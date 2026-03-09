import AVFoundation
import CoreGraphics
import UIKit

@Observable
final class VideoEncodingService: @unchecked Sendable {
    var isEncoding = false
    var progress: Double = 0

    private var backgroundTaskID: UIBackgroundTaskIdentifier = .invalid

    @MainActor
    func encodeVideo(for meeting: Meeting) async throws -> URL {
        guard let audioURL = meeting.audioFileURL else {
            throw VideoEncodingError.audioFileNotFound
        }
        guard FileManager.default.fileExists(atPath: audioURL.path) else {
            throw VideoEncodingError.audioFileNotFound
        }

        isEncoding = true
        progress = 0

        // Request background task time
        backgroundTaskID = await UIApplication.shared.beginBackgroundTask { [weak self] in
            self?.endBackgroundTask()
        }

        do {
            let outputURL = try await performEncoding(
                audioURL: audioURL,
                title: meeting.title,
                date: meeting.date,
                duration: meeting.duration
            )
            isEncoding = false
            progress = 1.0
            endBackgroundTask()
            return outputURL
        } catch {
            isEncoding = false
            progress = 0
            endBackgroundTask()
            throw error
        }
    }

    private func endBackgroundTask() {
        if backgroundTaskID != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTaskID)
            backgroundTaskID = .invalid
        }
    }

    // MARK: - Encoding Pipeline

    private func performEncoding(
        audioURL: URL,
        title: String,
        date: Date,
        duration: TimeInterval
    ) async throws -> URL {
        // Clean up previous temp files
        cleanupTempFiles()

        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("MeetingMind_\(UUID().uuidString).mp4")

        let videoSize = CGSize(width: 1080, height: 1920)
        let frameImage = renderFrame(
            title: title,
            date: date,
            duration: duration,
            size: videoSize
        )

        guard let cgImage = frameImage.cgImage else {
            throw VideoEncodingError.frameRenderingFailed
        }

        // Set up asset reader for audio
        let audioAsset = AVAsset(url: audioURL)
        let audioReader = try AVAssetReader(asset: audioAsset)

        let audioTracks = try await audioAsset.loadTracks(withMediaType: .audio)
        guard let audioTrack = audioTracks.first else {
            throw VideoEncodingError.audioTrackNotFound
        }

        let audioDuration = try await audioAsset.load(.duration)
        let totalSeconds = CMTimeGetSeconds(audioDuration)
        guard totalSeconds > 0 else {
            throw VideoEncodingError.invalidDuration
        }

        let audioOutputSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsNonInterleaved: false,
        ]
        let audioReaderOutput = AVAssetReaderTrackOutput(track: audioTrack, outputSettings: audioOutputSettings)
        audioReader.add(audioReaderOutput)

        // Set up asset writer
        let assetWriter = try AVAssetWriter(outputURL: outputURL, fileType: .mp4)

        // Video input
        let videoSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: Int(videoSize.width),
            AVVideoHeightKey: Int(videoSize.height),
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: totalSeconds > 7200 ? 500_000 : 1_000_000,
                AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
            ],
        ]
        let videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        let pixelBufferAdaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: videoInput,
            sourcePixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB,
                kCVPixelBufferWidthKey as String: Int(videoSize.width),
                kCVPixelBufferHeightKey as String: Int(videoSize.height),
            ]
        )
        assetWriter.add(videoInput)

        // Audio input
        let audioWriterSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderBitRateKey: 96000,
        ]
        let audioInput = AVAssetWriterInput(mediaType: .audio, outputSettings: audioWriterSettings)
        assetWriter.add(audioInput)

        // Start writing
        assetWriter.startWriting()
        assetWriter.startSession(atSourceTime: .zero)
        audioReader.startReading()

        // Write video frames (1 fps static image repeated)
        let fps: Int32 = 1
        let totalFrames = Int(ceil(totalSeconds)) * Int(fps)

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            videoInput.requestMediaDataWhenReady(on: DispatchQueue(label: "video.encoding.video")) {
                var frameIndex = 0
                while videoInput.isReadyForMoreMediaData {
                    if frameIndex >= totalFrames {
                        videoInput.markAsFinished()
                        continuation.resume()
                        return
                    }

                    let presentationTime = CMTime(value: CMTimeValue(frameIndex), timescale: fps)

                    if let pixelBuffer = self.createPixelBuffer(from: cgImage, size: videoSize) {
                        pixelBufferAdaptor.append(pixelBuffer, withPresentationTime: presentationTime)
                    }

                    frameIndex += 1
                }
            }
        }

        // Write audio samples
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            audioInput.requestMediaDataWhenReady(on: DispatchQueue(label: "video.encoding.audio")) { [weak self] in
                while audioInput.isReadyForMoreMediaData {
                    guard audioReader.status == .reading,
                          let sampleBuffer = audioReaderOutput.copyNextSampleBuffer() else {
                        audioInput.markAsFinished()
                        continuation.resume()
                        return
                    }

                    audioInput.append(sampleBuffer)

                    let sampleTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
                    let currentProgress = CMTimeGetSeconds(sampleTime) / totalSeconds
                    DispatchQueue.main.async {
                        self?.progress = min(currentProgress, 0.99)
                    }
                }
            }
        }

        // Finalize
        await assetWriter.finishWriting()

        if assetWriter.status == .failed {
            throw assetWriter.error ?? VideoEncodingError.encodingFailed
        }

        return outputURL
    }

    // MARK: - Frame Rendering

    private func renderFrame(title: String, date: Date, duration: TimeInterval, size: CGSize) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            let ctx = context.cgContext
            let rect = CGRect(origin: .zero, size: size)

            // Background: dark teal gradient
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            let gradientColors = [
                UIColor(red: 15/255, green: 23/255, blue: 42/255, alpha: 1.0).cgColor,
                UIColor(red: 13/255, green: 148/255, blue: 136/255, alpha: 0.3).cgColor,
                UIColor(red: 15/255, green: 23/255, blue: 42/255, alpha: 1.0).cgColor,
            ]
            if let gradient = CGGradient(colorsSpace: colorSpace, colors: gradientColors as CFArray, locations: [0, 0.5, 1]) {
                ctx.drawLinearGradient(gradient, start: CGPoint(x: size.width / 2, y: 0), end: CGPoint(x: size.width / 2, y: size.height), options: [])
            }

            // Waveform bars (decorative)
            let barCount = 60
            let barWidth: CGFloat = size.width / CGFloat(barCount * 2)
            let barSpacing = barWidth
            let centerY = size.height * 0.5
            let maxBarHeight: CGFloat = size.height * 0.15

            let tealColor = UIColor(red: 20/255, green: 184/255, blue: 166/255, alpha: 0.6)
            ctx.setFillColor(tealColor.cgColor)

            for i in 0..<barCount {
                // Pseudo-random bar heights based on index
                let seed = sin(Double(i) * 0.3) * cos(Double(i) * 0.7) * 0.5 + 0.5
                let barHeight = maxBarHeight * CGFloat(seed * 0.8 + 0.2)
                let x = CGFloat(i) * (barWidth + barSpacing) + (size.width - CGFloat(barCount) * (barWidth + barSpacing)) / 2
                let barRect = CGRect(x: x, y: centerY - barHeight / 2, width: barWidth, height: barHeight)
                let barPath = UIBezierPath(roundedRect: barRect, cornerRadius: barWidth / 2)
                ctx.addPath(barPath.cgPath)
                ctx.fillPath()
            }

            // Title
            let titleFont = UIFont.systemFont(ofSize: 48, weight: .bold).rounded()
            let titleAttrs: [NSAttributedString.Key: Any] = [
                .font: titleFont,
                .foregroundColor: UIColor.white,
            ]
            let titleString = title as NSString
            let titleSize = titleString.boundingRect(
                with: CGSize(width: size.width - 120, height: 200),
                options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine],
                attributes: titleAttrs,
                context: nil
            )
            let titleOrigin = CGPoint(x: (size.width - titleSize.width) / 2, y: size.height * 0.2)
            titleString.draw(
                with: CGRect(origin: titleOrigin, size: CGSize(width: size.width - 120, height: 200)),
                options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine],
                attributes: titleAttrs,
                context: nil
            )

            // Date
            let dateString = date.formatted(date: .long, time: .shortened) as NSString
            let dateFont = UIFont.systemFont(ofSize: 28, weight: .medium).rounded()
            let dateAttrs: [NSAttributedString.Key: Any] = [
                .font: dateFont,
                .foregroundColor: UIColor.white.withAlphaComponent(0.7),
            ]
            let dateSize = dateString.size(withAttributes: dateAttrs)
            let dateOrigin = CGPoint(x: (size.width - dateSize.width) / 2, y: size.height * 0.2 + titleSize.height + 20)
            dateString.draw(at: dateOrigin, withAttributes: dateAttrs)

            // Duration
            let minutes = Int(duration) / 60
            let seconds = Int(duration) % 60
            let durationText = "\(minutes)m \(seconds)s" as NSString
            let durationFont = UIFont.systemFont(ofSize: 24, weight: .regular).rounded()
            let durationAttrs: [NSAttributedString.Key: Any] = [
                .font: durationFont,
                .foregroundColor: UIColor.white.withAlphaComponent(0.5),
            ]
            let durationSize = durationText.size(withAttributes: durationAttrs)
            let durationOrigin = CGPoint(x: (size.width - durationSize.width) / 2, y: dateOrigin.y + dateSize.height + 12)
            durationText.draw(at: durationOrigin, withAttributes: durationAttrs)

            // MeetingMind watermark at bottom
            let watermarkFont = UIFont.systemFont(ofSize: 20, weight: .semibold).rounded()
            let watermarkAttrs: [NSAttributedString.Key: Any] = [
                .font: watermarkFont,
                .foregroundColor: UIColor.white.withAlphaComponent(0.3),
            ]
            let watermark = "MeetingMind" as NSString
            let watermarkSize = watermark.size(withAttributes: watermarkAttrs)
            let watermarkOrigin = CGPoint(x: (size.width - watermarkSize.width) / 2, y: size.height - 80)
            watermark.draw(at: watermarkOrigin, withAttributes: watermarkAttrs)
        }
    }

    // MARK: - Pixel Buffer

    private func createPixelBuffer(from cgImage: CGImage, size: CGSize) -> CVPixelBuffer? {
        var pixelBuffer: CVPixelBuffer?
        let attrs: [String: Any] = [
            kCVPixelBufferCGImageCompatibilityKey as String: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey as String: true,
        ]

        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            Int(size.width),
            Int(size.height),
            kCVPixelFormatType_32ARGB,
            attrs as CFDictionary,
            &pixelBuffer
        )

        guard status == kCVReturnSuccess, let buffer = pixelBuffer else { return nil }

        CVPixelBufferLockBaseAddress(buffer, [])
        let pixelData = CVPixelBufferGetBaseAddress(buffer)
        let rgbColorSpace = CGColorSpaceCreateDeviceRGB()

        guard let context = CGContext(
            data: pixelData,
            width: Int(size.width),
            height: Int(size.height),
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
            space: rgbColorSpace,
            bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue
        ) else {
            CVPixelBufferUnlockBaseAddress(buffer, [])
            return nil
        }

        context.draw(cgImage, in: CGRect(origin: .zero, size: size))
        CVPixelBufferUnlockBaseAddress(buffer, [])

        return buffer
    }

    // MARK: - Cleanup

    func cleanupTempFiles() {
        let tempDir = FileManager.default.temporaryDirectory
        guard let files = try? FileManager.default.contentsOfDirectory(at: tempDir, includingPropertiesForKeys: nil) else { return }
        for file in files where file.lastPathComponent.hasPrefix("MeetingMind_") && file.pathExtension == "mp4" {
            try? FileManager.default.removeItem(at: file)
        }
    }
}

// MARK: - UIFont Rounded Extension

private extension UIFont {
    func rounded() -> UIFont {
        guard let descriptor = fontDescriptor.withDesign(.rounded) else { return self }
        return UIFont(descriptor: descriptor, size: pointSize)
    }
}

// MARK: - Errors

enum VideoEncodingError: LocalizedError {
    case audioFileNotFound
    case audioTrackNotFound
    case invalidDuration
    case frameRenderingFailed
    case encodingFailed

    var errorDescription: String? {
        switch self {
        case .audioFileNotFound:
            "Audio file not found. The recording may have been deleted."
        case .audioTrackNotFound:
            "Could not read audio track from the recording file."
        case .invalidDuration:
            "The audio file has no content to encode."
        case .frameRenderingFailed:
            "Failed to generate the video frame image."
        case .encodingFailed:
            "Video encoding failed. Please try again."
        }
    }
}
