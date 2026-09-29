import SwiftUI

struct FixedLyricsView: View {
    let lines: [LyricLine]
    let progress: Double
    @EnvironmentObject private var player: RhythmPlayer

    private var activeIndex: Int {
        guard !lines.isEmpty else { return 0 }
        return max(0, lines.lastIndex(where: { $0.time <= progress }) ?? 0)
    }

    var body: some View {
        GeometryReader { geo in
            ScrollViewReader { proxy in
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 14) {
                        ForEach(Array(lines.enumerated()), id: \.element.id) { index, line in
                            Text(line.text)
                                .font(.system(size: index == activeIndex ? 24 : 18, weight: index == activeIndex ? .bold : .semibold, design: .rounded))
                                .foregroundStyle(Color.primary.opacity(index == activeIndex ? 1 : 0.28))
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: max(120, geo.size.width - 34))
                                .fixedSize(horizontal: false, vertical: true)
                                .contentShape(Rectangle())
                                .onTapGesture { player.seek(line.time) }
                                .id(line.id)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 14)
                    .padding(.vertical, max(36, geo.size.height * 0.25))
                }
                .mask(LinearGradient(colors: [.clear, .black, .black, .clear], startPoint: .top, endPoint: .bottom))
                .onChange(of: activeIndex) { _, index in
                    guard lines.indices.contains(index) else { return }
                    withAnimation(.easeInOut(duration: 0.35)) { proxy.scrollTo(lines[index].id, anchor: .center) }
                }
                .onAppear {
                    guard lines.indices.contains(activeIndex) else { return }
                    proxy.scrollTo(lines[activeIndex].id, anchor: .center)
                }
            }
        }
    }
}

struct FixedPlayerBackground: View {
    let url: URL?
    var body: some View {
        ZStack {
            RhythmTheme.background.ignoresSafeArea()
            AsyncImage(url: url) { phase in
                if case .success(let image) {
                    image.resizable().scaledToFill().blur(radius: 70).opacity(0.28)
                }
            }
            LinearGradient(colors: [RhythmTheme.background.opacity(0.12), RhythmTheme.background.opacity(0.94)], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
        }
    }
}
