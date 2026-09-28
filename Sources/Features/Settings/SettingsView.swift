import SwiftUI
import AVFoundation

struct SettingsView: View {
    @AppStorage("selectedTheme") private var selectedTheme = "Dark"
    @AppStorage("audioQuality") private var audioQuality = "High"
    @AppStorage("eqPreset") private var eqPreset = "Flat"
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.monetBackground.ignoresSafeArea()
                
                Form {
                    Section(header: Text("Внешний вид").foregroundColor(.monetSecondary)) {
                        Picker("Тема", selection: $selectedTheme) {
                            Text("Темная").tag("Dark")
                            Text("Светлая").tag("Light")
                            Text("Системная").tag("System")
                        }
                        .onChange(of: selectedTheme) { _ in
                            applyTheme()
                        }
                    }
                    .listRowBackground(Color.monetSurface)
                    
                    Section(header: Text("Звук").foregroundColor(.monetSecondary)) {
                        Picker("Качество звука", selection: $audioQuality) {
                            Text("Экономия трафика").tag("Low")
                            Text("Высокое (128 kbps)").tag("High")
                            Text("Максимальное (256 kbps)").tag("Lossless")
                        }
                        
                        Picker("Эквалайзер", selection: $eqPreset) {
                            Text("Отключен").tag("Flat")
                            Text("Басс (Bass Boost)").tag("Bass")
                            Text("Вокал").tag("Vocal")
                            Text("Хип-Хоп").tag("HipHop")
                            Text("Электронная").tag("Electronic")
                        }
                        .onChange(of: eqPreset) { _ in
                            AudioPlayerService.shared.applyEQ(preset: eqPreset)
                        }
                    }
                    .listRowBackground(Color.monetSurface)
                    
                    Section(header: Text("Сервер полных треков").foregroundColor(.monetSecondary), footer: Text("Укажите IP-адрес вашего ПК в Wi-Fi сети.\nПример: 192.168.1.55\nСервер запускается командой npm start в папке Backend.").foregroundColor(.monetSecondary.opacity(0.6))) {
                        HStack {
                            Image(systemName: "server.rack")
                                .foregroundColor(MonetTheme.accent)
                            TextField("IP адрес", text: Binding(
                                get: { UserDefaults.standard.string(forKey: "backendURL") ?? "" },
                                set: { UserDefaults.standard.set($0, forKey: "backendURL") }
                            ))
                            .foregroundColor(.white)
                            .keyboardType(.numbersAndPunctuation)
                            .autocapitalization(.none)
                        }
                    }
                    .listRowBackground(Color.monetSurface)
                    
                    Section(header: Text("О приложении").foregroundColor(.monetSecondary)) {
                        HStack {
                            Text("Версия")
                            Spacer()
                            Text("1.0.0")
                                .foregroundColor(.monetSecondary)
                        }
                        HStack {
                            Text("Разработчик")
                            Spacer()
                            Text("Monet Music")
                                .foregroundColor(.monetSecondary)
                        }
                    }
                    .listRowBackground(Color.monetSurface)
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Настройки")
            .navigationBarTitleDisplayMode(.large)
            .onAppear {
                applyTheme()
            }
        }
    }
    
    private func applyTheme() {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = scene.windows.first else { return }
        
        switch selectedTheme {
        case "Light":
            window.overrideUserInterfaceStyle = .light
        case "Dark":
            window.overrideUserInterfaceStyle = .dark
        default:
            window.overrideUserInterfaceStyle = .unspecified
        }
    }
}
