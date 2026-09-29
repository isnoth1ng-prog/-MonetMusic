import SwiftUI

struct ConfigScreen: View {
    @StateObject private var appearance = RhythmAppearance.shared
    @AppStorage("themeMode") private var themeMode = "dark"
    @AppStorage("accentHex") private var accentHex = "5A8CFF"

    private let accents: [(String, String)] = [
        ("5A8CFF", "Синий"), ("A78BFA", "Фиолетовый"),
        ("34D399", "Зелёный"), ("FF9F43", "Оранжевый")
    ]

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                section("Внешний вид") {
                    HStack {
                        Label("Тема", systemImage: "circle.lefthalf.filled")
                        Spacer()
                        Picker("", selection: Binding(
                            get: { themeMode },
                            set: { themeMode = $0; appearance.applyTheme($0) }
                        )) {
                            Text("Тёмная").tag("dark")
                            Text("Система").tag("system")
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 180)
                    }

                    HStack(spacing: 14) {
                        Text("Акцент")
                        Spacer()
                        ForEach(accents, id: \.0) { item in
                            Button {
                                accentHex = item.0
                                appearance.applyAccent(item.0)
                            } label: {
                                Circle()
                                    .fill(Color(hex: item.0))
                                    .frame(width: 30, height: 30)
                                    .overlay {
                                        if accentHex.uppercased() == item.0 {
                                            Image(systemName: "checkmark")
                                                .font(.system(size: 11, weight: .bold))
                                                .foregroundStyle(.white)
                                        }
                                    }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.top, 8)
                }

                section("Воспроизведение") {
                    row("Основной источник", "music.note", "Apple Music")
                    row("Резерв", "arrow.triangle.2.circlepath", "Audius · Piped")
                    row("Качество", "waveform", "Полные треки")
                }

                section("Rhythm") {
                    row("Версия", "number", "5.4")
                    Text("Apple Music используется для полного воспроизведения каталога. Фоновое аудио включено.")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(RhythmTheme.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 8)
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 8)
            .padding(.bottom, 130)
        }
        .background(RhythmTheme.background)
        .navigationTitle("Настройки")
        .navigationBarTitleDisplayMode(.large)
        .preferredColorScheme(themeMode == "dark" ? .dark : nil)
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).sectionTitle()
            VStack(alignment: .leading) {
                content()
            }
            .padding(14)
            .rhythmGlass(20)
        }
    }

    private func row(_ title: String, _ icon: String, _ value: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .frame(width: 24)
                .foregroundStyle(RhythmTheme.accent)
            Text(title).font(.system(size: 14, weight: .medium))
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(RhythmTheme.secondary)
        }
        .padding(.vertical, 9)
    }
}
