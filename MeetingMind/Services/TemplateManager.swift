import Foundation

@Observable
final class TemplateManager {
    private(set) var customTemplates: [MeetingTemplate] = []

    private let customTemplatesKey = "customMeetingTemplates"

    var allTemplates: [MeetingTemplate] {
        MeetingTemplate.builtInTemplates + customTemplates
    }

    init() {
        loadCustomTemplates()
    }

    func template(for id: String?) -> MeetingTemplate? {
        guard let id else { return nil }
        return allTemplates.first { $0.id == id }
    }

    func addCustomTemplate(_ template: MeetingTemplate) {
        customTemplates.append(template)
        saveCustomTemplates()
    }

    func deleteCustomTemplate(id: String) {
        customTemplates.removeAll { $0.id == id }
        saveCustomTemplates()
    }

    private func loadCustomTemplates() {
        guard let data = UserDefaults.standard.data(forKey: customTemplatesKey) else { return }
        customTemplates = (try? JSONDecoder().decode([MeetingTemplate].self, from: data)) ?? []
    }

    private func saveCustomTemplates() {
        guard let data = try? JSONEncoder().encode(customTemplates) else { return }
        UserDefaults.standard.set(data, forKey: customTemplatesKey)
    }
}
