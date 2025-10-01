import SwiftUI
import UniformTypeIdentifiers
import MobileCoreServices
import Combine

struct TodoItem: Identifiable, Codable, Equatable {
    var id: Int
    var text: String
    var completed: Bool
}

private struct TaskPayload: Codable {
    let text: String
    let completed: Bool
}

private struct TaskResponse: Codable {
    let message: String?
    let task: TodoItem?
}

enum APIError: Error, LocalizedError {
    case badStatus(Int)
    case missingTask

    var errorDescription: String? {
        switch self {
        case .badStatus(let code):
            return "Неверный статус ответа: \(code)"
        case .missingTask:
            return "В ответе сервера отсутствует задача"
        }
    }
}

final class APIClient {
    private let baseURL = URL(string: "http://192.168.0.7:8000/api")!
    private let session: URLSession
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    init(session: URLSession = .shared) {
        self.session = session
    }

    private func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw APIError.badStatus(-1)
        }
        return (data, http)
    }

    func fetchTasks() async throws -> [TodoItem] {
        let request = URLRequest(url: baseURL.appendingPathComponent("tasks"))
        let (data, response) = try await data(for: request)
        guard response.statusCode == 200 else { throw APIError.badStatus(response.statusCode) }
        return try decoder.decode([TodoItem].self, from: data)
    }

    func createTask(text: String, completed: Bool) async throws -> TodoItem {
        var request = URLRequest(url: baseURL.appendingPathComponent("tasks"))
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try encoder.encode(TaskPayload(text: text, completed: completed))

        let (data, response) = try await data(for: request)
        guard response.statusCode == 200 else { throw APIError.badStatus(response.statusCode) }
        let decoded = try decoder.decode(TaskResponse.self, from: data)
        guard let task = decoded.task else { throw APIError.missingTask }
        return task
    }

    func updateTask(id: Int, text: String, completed: Bool) async throws -> TodoItem {
        var request = URLRequest(url: baseURL.appendingPathComponent("tasks/\(id)"))
        request.httpMethod = "PUT"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try encoder.encode(TaskPayload(text: text, completed: completed))

        let (data, response) = try await data(for: request)
        guard response.statusCode == 200 else { throw APIError.badStatus(response.statusCode) }
        let decoded = try decoder.decode(TaskResponse.self, from: data)
        guard let task = decoded.task else { throw APIError.missingTask }
        return task
    }

    func toggleTask(id: Int) async throws -> TodoItem {
        var request = URLRequest(url: baseURL.appendingPathComponent("tasks/\(id)/toggle"))
        request.httpMethod = "PATCH"

        let (data, response) = try await data(for: request)
        guard response.statusCode == 200 else { throw APIError.badStatus(response.statusCode) }
        let decoded = try decoder.decode(TaskResponse.self, from: data)
        guard let task = decoded.task else { throw APIError.missingTask }
        return task
    }

    func deleteTask(id: Int) async throws {
        var request = URLRequest(url: baseURL.appendingPathComponent("tasks/\(id)"))
        request.httpMethod = "DELETE"

        let (_, response) = try await data(for: request)
        guard response.statusCode == 200 else { throw APIError.badStatus(response.statusCode) }
    }
}

@MainActor
final class TodoViewModel: ObservableObject {
    @Published var items: [TodoItem] = []
    @Published var lastErrorMessage: String?

    private let api = APIClient()

    init() {
        Task { await load() }
    }

    func load() async {
        do {
            items = try await api.fetchTasks()
        } catch {
            reportError("Не удалось загрузить задачи", error)
        }
    }

    func add(text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        Task {
            do {
                _ = try await api.createTask(text: trimmed, completed: false)
                await load()
            } catch {
                reportError("Не удалось добавить задачу", error)
            }
        }
    }

    func delete(at offsets: IndexSet) {
        let ids = offsets.map { items[$0].id }

        Task {
            do {
                for id in ids {
                    try await api.deleteTask(id: id)
                }
                await load()
            } catch {
                reportError("Не удалось удалить задачу", error)
            }
        }
    }

    func update(_ item: TodoItem, newText: String) {
        let trimmed = newText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        Task {
            do {
                _ = try await api.updateTask(id: item.id, text: trimmed, completed: item.completed)
                await load()
            } catch {
                reportError("Не удалось обновить задачу", error)
            }
        }
    }

    func toggle(_ item: TodoItem) {
        Task {
            do {
                _ = try await api.toggleTask(id: item.id)
                await load()
            } catch {
                reportError("Не удалось изменить статус", error)
            }
        }
    }

    func importFromData(_ data: Data) async throws {
        let decoded = try JSONDecoder().decode([TodoItem].self, from: data)
        for item in decoded {
            _ = try await api.createTask(text: item.text, completed: item.completed)
        }
        await load()
    }

    func exportURL() -> URL? {
        do {
            let tmp = FileManager.default.temporaryDirectory
            let url = tmp.appendingPathComponent("todo_export_\(Int(Date().timeIntervalSince1970)).json")
            let data = try JSONEncoder().encode(items)
            try data.write(to: url)
            return url
        } catch {
            reportError("Не удалось экспортировать задачи", error)
            return nil
        }
    }

    func clearError() {
        lastErrorMessage = nil
    }

    private func reportError(_ message: String, _ error: Error) {
        print(message, error)
        lastErrorMessage = message
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
