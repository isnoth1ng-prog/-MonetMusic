import SwiftUI

struct TrackRowView: View {
    let track: Track
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                AsyncCoverImage(url: track.highResCoverURL, size: 56)

                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 6) {
                        Text(track.title)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .lineLimit(1)

                        if track.isExplicit {
                            Image(systemName: "e.square.fill")
                                .font(.system(size: 11))
                                .foregroundColor(.monetSecondary)
                        }
                    }

                    Text(track.artist)
                        .font(.system(size: 13))
                        .foregroundColor(.monetSecondary)
                        .lineLimit(1)
                }

                Spacer()

                Image(systemName: "play.circle")
                    .font(.system(size: 22))
                    .foregroundColor(.white.opacity(0.38))
            }
            .padding(.horizontal, MonetTheme.padding)
            .padding(.vertical, 9)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
