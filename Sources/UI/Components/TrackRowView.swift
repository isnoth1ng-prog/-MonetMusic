import SwiftUI

struct TrackRowView: View {
    let track: Track
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                AsyncCoverImage(url: track.coverURL, size: 56)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(track.title)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    HStack(spacing: 4) {
                        if track.isExplicit {
                            Image(systemName: "e.square.fill")
                                .font(.system(size: 12))
                                .foregroundColor(.monetSecondary)
                        }
                        Text(track.artist)
                            .font(.system(size: 14))
                            .foregroundColor(.monetSecondary)
                            .lineLimit(1)
                    }
                }
                
                Spacer()
                
                Button(action: {
                    // Quick options like Add to library could go here
                }) {
                    Image(systemName: "ellipsis")
                        .foregroundColor(.monetSecondary)
                        .padding(8)
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, MonetTheme.padding)
            .background(Color.monetBackground.opacity(0.01)) // Make entire row clickable
        }
        .buttonStyle(PlainButtonStyle())
    }
}
