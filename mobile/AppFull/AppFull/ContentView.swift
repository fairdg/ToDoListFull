import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @EnvironmentObject var vm: TodoViewModel
    @State private var showingAdd = false
    @State private var showingImporter = false
    @State private var showingExporter = false
    @State private var editItem: TodoItem? = nil
    @State private var activityURL: URL? = nil
    @State private var showAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        NavigationView {
            List {
                ForEach(vm.items) { item in
                    HStack {
                        Button(action: { vm.toggle(item) }) {
                            Image(systemName: item.completed ? "checkmark.circle.fill" : "circle")
                                .imageScale(.large)
                        }
                        .buttonStyle(BorderlessButtonStyle())
                        
                        VStack(alignment: .leading) {
                            Text(item.text)
                                .strikethrough(item.completed, color: .primary)
                                .foregroundColor(item.completed ? .secondary : .primary)
                                .lineLimit(nil)
                                .onTapGesture {
                                    editItem = item
                                }
                        }
                        Spacer()
                    }
                }
                .onDelete(perform: vm.delete)
            }
            .listStyle(PlainListStyle())
            .navigationTitle("Список дел")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    HStack {
                        Button(action: {
                            showingImporter = true
                        }) {
                            Image(systemName: "folder.badge.plus")
                        }
                     /*   Button(action: {
                            vm.debugPrintFile()
                        }){
                            Image(systemName: "doc.text.magnifyingglass")
                        }*/
                    }
                }
               
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack {
                        Button(action: {
                            if let url = vm.exportURL() {
                                activityURL = url
                                showingExporter = true
                            } else {
                                alertMessage = "Невозможно создать файл для экспорта."
                                showAlert = true
                            }
                        }) {
                            Image(systemName: "square.and.arrow.up")
                        }
                        Button(action: { showingAdd = true }) {
                            Image(systemName: "plus")
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showingAdd) {
            EditTodoView(mode: .new) { text in
                vm.add(text: text)
                showingAdd = false
            } onCancel: {
                showingAdd = false
            }
        }
        .sheet(item: $editItem) { item in
            EditTodoView(mode: .edit(item)) { newText in
                vm.update(item, newText: newText)
                editItem = nil
            } onCancel: {
                editItem = nil
            }
        }
        .fileImporter(isPresented: $showingImporter, allowedContentTypes: [.json], allowsMultipleSelection: false) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                do {
                    let data = try Data(contentsOf: url)
                    Task {
                        do {
                            try await vm.importFromData(data)
                        } catch {
                            alertMessage = "Ошибка импорта: \(error.localizedDescription)"
                            showAlert = true
                        }
                    }
                } catch {
                    alertMessage = "Ошибка импорта: \(error.localizedDescription)"
                    showAlert = true
                }
            case .failure(let error):
                alertMessage = "Picker error: \(error.localizedDescription)"
                showAlert = true
            }
        }
        .sheet(isPresented: $showingExporter, onDismiss: {
            if let u = activityURL {
                try? FileManager.default.removeItem(at: u)
                activityURL = nil
            }
        }) {
            if let url = activityURL {
                ActivityView(activityItems: [url])
            } else {
                Text("Нет файла для экспорта")
            }
        }
        .alert(isPresented: $showAlert) {
            Alert(title: Text("Внимание"), message: Text(alertMessage), dismissButton: .default(Text("ОК")))
        }
        .onChangeCompat(of: vm.lastErrorMessage) { newValue in
            if let message = newValue {
                alertMessage = message
                showAlert = true
                vm.clearError()
            }
        }
    }
}

struct EditTodoView: View {
    enum Mode {
        case new
        case edit(TodoItem)
    }
    
    var mode: Mode
    var onSave: (String) -> Void
    var onCancel: () -> Void
    
    @State private var text: String = ""
    @Environment(\.presentationMode) var presentation
    
    init(mode: Mode, onSave: @escaping (String) -> Void, onCancel: @escaping () -> Void) {
        self.mode = mode
        self.onSave = onSave
        self.onCancel = onCancel
        _text = State(initialValue: {
            switch mode {
            case .new: return ""
            case .edit(let item): return item.text
            }
        }())
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Описание")) {
                    TextEditor(text: $text)
                        .frame(minHeight: 120)
                }
            }
            .navigationTitle(modeTitle)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") {
                        onSave(text)
                        presentation.wrappedValue.dismiss()
                    }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") {
                        onCancel()
                        presentation.wrappedValue.dismiss()
                    }
                }
            }
        }
    }
    
    var modeTitle: String {
        switch mode {
        case .new: return "Новое дело"
        case .edit: return "Редактировать дело"
        }
    }
}

struct ActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]
    let applicationActivities: [UIActivity]? = nil
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: applicationActivities)
        if let windowScene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }),
           let window = windowScene.windows.first,
           let rootView = window.rootViewController?.view {
            controller.popoverPresentationController?.sourceView = rootView
            controller.popoverPresentationController?.sourceRect = CGRect(x: rootView.bounds.midX, y: rootView.bounds.midY, width: 0, height: 0)
            controller.popoverPresentationController?.permittedArrowDirections = []
        }
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

private extension View {
    @ViewBuilder
    func onChangeCompat<Value: Equatable>(of value: Value, perform action: @escaping (Value) -> Void) -> some View {
        if #available(iOS 17.0, *) {
            onChange(of: value, initial: false) { _, newValue in
                action(newValue)
            }
        } else {
            onChange(of: value, perform: action)
        }
    }
}
