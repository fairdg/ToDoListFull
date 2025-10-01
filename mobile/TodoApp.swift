import SwiftUI
import UniformTypeIdentifiers
import MobileCoreServices

struct TodoItem: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var text: String
    var done: Bool = false
}

final class TodoViewModel: ObservableObject {
    @Published var items: [TodoItem] = [] {
        didSet {
            saveToDocuments()
        }
    }
    private let fileName = "todo_list.json"
    
    init() {
        loadFromDocuments()
    }
    
    
/*    func debugPrintFile() {
        guard let url = documentsURL()?.appendingPathComponent(fileName) else { return }
        do {
            let data = try Data(contentsOf: url)
            if let jsonString = String(data: data, encoding: .utf8) {
                print(" todo_list.json content:\n\(jsonString)")
                print("Файл лежит по пути:", url.path)
            } else {
                print(" Не удалось декодировать содержимое файла в строку")
            }
        } catch {
            print(" Ошибка чтения файла:", error)
        }
    }*/
    func add(text: String) {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        items.append(TodoItem(text: text))
    }
    
    func delete(at offsets: IndexSet) {
        items.remove(atOffsets: offsets)
    }
    
    func update(_ item: TodoItem) {
        if let i = items.firstIndex(where: { $0.id == item.id }) {
            items[i] = item
        }
    }
    
    func toggleDone(_ item: TodoItem) {
        if let i = items.firstIndex(where: { $0.id == item.id }) {
            items[i].done.toggle()
        }
    }
    
    private func documentsURL() -> URL? {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
    }
    
    private func saveToDocuments() {
        guard let url = documentsURL()?.appendingPathComponent(fileName) else { return }
        do {
            let data = try JSONEncoder().encode(items)
            try data.write(to: url, options: .atomic)
        } catch {
            print("Save error:", error)
        }
    }
    
    private func loadFromDocuments() {
        guard let url = documentsURL()?.appendingPathComponent(fileName), FileManager.default.fileExists(atPath: url.path) else { return }
        do {
            let data = try Data(contentsOf: url)
            let decoded = try JSONDecoder().decode([TodoItem].self, from: data)
            items = decoded
        } catch {
            print("Load error:", error)
        }
    }
    
    func importFromData(_ data: Data) throws {
        let decoded = try JSONDecoder().decode([TodoItem].self, from: data)
        items = decoded
    }
    
    func exportURL() -> URL? {
        do {
            let tmp = FileManager.default.temporaryDirectory
            let url = tmp.appendingPathComponent("todo_export_\(Int(Date().timeIntervalSince1970)).json")
            let data = try JSONEncoder().encode(items)
            try data.write(to: url)
            return url
        } catch {
            print("Export error:", error)
            return nil
        }
    }
}

@main
struct TodoApp: App {
    @StateObject private var vm = TodoViewModel()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(vm)
        }
    }
}
