import SwiftUI

struct SettingsView: View {
    @AppStorage("themeMode") private var themeMode = "dark"
    @AppStorage("accentHex") private var accentHex = "5A8CFF"
    @EnvironmentObject private var store: ListeningStore
    @StateObject private var appearance = RhythmAppearance.shared

    private let accents = [
        "5A8CFF", "9B6BFF", "34C759", "FF9F0A",
        "FF375F", "64D2FF", "FFFFFF"
    ]

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 22) {
                settingsSection("Внешний вид") {
                    Text("Тема")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(RhythmTheme.secondary)

                    HStack(spacing: 8) {
                        ThemeChoice(title: "Тёмная", icon: "moon.fill", selected: themeMode == "dark") {
                            themeMode = "dark"
                            appearance.applyTheme("dark")
                        }
                        ThemeChoice(title: "Система", icon: "circle.lefthalf.filled", selected: themeMode == "system") {
                            themeMode = "system"
                            appearance.applyTheme("system")
                        }
                        ThemeChoice(title: "Светлая", icon: "sun.max.fill", selected: themeMode == "light") {
                            themeMode = "light"
                            appearance.applyTheme("light")
                        }
                    }

                    Text("Акцент")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(RhythmTheme.secondary)
                        .padding(.top, 5)

                    HStack(spacing: 13) {
                        ForEach(accents, id: \.self) { hex in
                            Button {
                                accentHex = hex
                                appearance.applyAccent(hex)
                            } label: {
                                Circle()
                                    .fill(Color(hex: hex))
                                    .frame(width: 31, height: 31)
                                    .overlay {
                                        Circle()
                                            .stroke(Color.primary, lineWidth: accentHex == hex ? 2.2 : 0)
                                            .padding(-3)
                                    }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                settingsSection("Источники") {
                    HStack(spacing: 12) {
                        Image(systemName: "dot.radiowaves.left.and.right")
                            .font(.system(size: 19, weight: .semibold))
                            .frame(width: 42, height: 42)
                            .rhythmGlass(21)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Полное воспроизведение")
                                .font(.system(size: 15, weight: .semibold))
                            Text("Audius → Piped. Без локальных файлов и 30-секундных превью.")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(RhythmTheme.secondary)
                        }

                        Spacer()
                    }
                }

                settingsSection("Данные") {
                    Button("Очистить историю", role: .destructive) {
                        store.clearHistory()
                    }
                }

                settingsSection("Rhythm") {
                    LabeledContent("Версия", value: "5.1")
                    LabeledContent("Источники", value: "Audius full stream + Piped")
                    LabeledContent("Тексты", value: "LRCLIB")
                    LabeledContent("Wave", value: "Адаптивная, трек за треком")
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 8)
            .padding(.bottom, 130)
        }
        .background(RhythmTheme.background)
        .navigationTitle("Настройки")
        .navigationBarTitleDisplayMode(.large)
    }

    private func settingsSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .bold))
                .tracking(1.8)
                .foregroundStyle(RhythmTheme.secondary)

            VStack(alignment: .leading, spacing: 14) {
                content()
            }
            .padding(16)
            .rhythmGlass(24)
        }
    }
}

struct ThemeChoice: View {
    let title: String
    let icon: String
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 7) {
                Image(systemName: icon)
                Text(title)
                    .font(.system(size: 10, weight: .semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .foregroundStyle(selected ? RhythmTheme.accent : Color.primary)
            .background(selected ? RhythmTheme.accent.opacity(0.12) : Color.clear, in: RoundedRectangle(cornerRadius: 15))
        }
        .buttonStyle(.plain)
    }
}

struct MiniPlayerView: View {
    @EnvironmentObject private var player: RhythmPlayer
    let open: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Button(action: open) {
                HStack(spacing: 11) {
                    CoverView(url: player.currentTrack?.highResCoverURL, size: 46, radius: 13)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(player.currentTrack?.title ?? "")
                            .font(.system(size: 14, weight: .semibold))
                            .lineLimit(1)
                        Text(player.currentTrack?.artist ?? "")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(RhythmTheme.secondary)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 0)
                }
            }
            .buttonStyle(.plain)

            Button { player.toggle() } label: {
                Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 13, weight: .bold))
                    .frame(width: 38, height: 38)
                    .background(Color.primary, in: Circle())
                    .foregroundStyle(RhythmTheme.background)
            }
        }
        .padding(6)
        .rhythmGlass(20)
        .padding(.horizontal, 2)
    }
}
