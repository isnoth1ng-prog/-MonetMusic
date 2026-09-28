import SwiftUI

struct SettingsView: View {
    @AppStorage("audioQuality") private var audioQuality = "High"
    @AppStorage("useBackend") private var useBackend = false
    @AppStorage("backendURL") private var backendURL = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Звук") {
                    Picker("Качество", selection: $audioQuality) {
                        Text("Экономия").tag("Low")
                        Text("Высокое").tag("High")
                        Text("Максимальное").tag("Lossless")
                    }
                }

                Section {
                    Toggle("Сервер полных треков", isOn: $useBackend)

                    if useBackend {
                        TextField("https://адрес-сервера", text: $backendURL)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .keyboardType(.URL)
                    }
                } header: {
                    Text("Дополнительный источник")
                } footer: {
                    Text("По умолчанию Rhythm играет напрямую из доступного preview. Сервер нужен только если ты действительно запустил свой /stream.")
                }

                Section("Персонализация") {
                    Button("Очистить историю прослушивания") {
                        ListeningHistory.shared.clear()
                    }
                    .foregroundColor(.red)
                }

                Section("О Rhythm") {
                    LabeledContent("Версия", value: "2.1.0")
                    LabeledContent("Приложение", value: "Rhythm")
                    LabeledContent("Музыкальный каталог", value: "iTunes Search")
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.monetBackground)
            .navigationTitle("Настройки")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}
