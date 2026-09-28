import SwiftUI
import AVFoundation

struct SettingsView: View {
    @AppStorage("audioQuality") private var audioQuality = "High"
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.monetBackground.ignoresSafeArea()
                
                Form {
                    Section(header: Text("Звук").foregroundColor(.monetSecondary)) {
                        Picker("Качество звука", selection: $audioQuality) {
                            Text("Экономия трафика").tag("Low")
                            Text("Высокое (128 kbps)").tag("High")
                            Text("Максимальное (256 kbps)").tag("Lossless")
                        }
                    }
                    .listRowBackground(Color.monetSurface)
                    
                    Section(header: Text("Сервер полных треков").foregroundColor(.monetSecondary), footer: Text("Для удаленного прослушивания запустите на ПК: npx localtunnel --port 3000 и вставьте сюда полученную ссылку (без https://)").foregroundColor(.monetSecondary.opacity(0.6))) {
                        HStack {
                            Image(systemName: "server.rack")
                                .foregroundColor(MonetTheme.accent)
                            TextField("URL или IP адрес", text: Binding(
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
        }
    }
}
