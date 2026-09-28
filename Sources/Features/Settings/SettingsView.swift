import SwiftUI

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
                            Text("Светлая").tag("Light")
                            Text("Темная").tag("Dark")
                            Text("Системная").tag("System")
                        }
                    }
                    .listRowBackground(Color.monetSurface)
                    
                    Section(header: Text("Звук").foregroundColor(.monetSecondary)) {
                        Picker("Качество звука", selection: $audioQuality) {
                            Text("Экономия трафика").tag("Low")
                            Text("Высокое").tag("High")
                            Text("Lossless (Максимальное)").tag("Lossless")
                        }
                        
                        Picker("Эквалайзер", selection: $eqPreset) {
                            Text("Отключен").tag("Flat")
                            Text("Басс (Bass Boost)").tag("Bass")
                            Text("Вокал").tag("Vocal")
                            Text("Хип-Хоп").tag("HipHop")
                            Text("Электронная").tag("Electronic")
                        }
                    }
                    .listRowBackground(Color.monetSurface)
                    
                    Section(header: Text("Информация").foregroundColor(.monetSecondary)) {
                        HStack {
                            Text("Версия")
                            Spacer()
                            Text("1.0.0 (Beta)")
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
