import SwiftUI

struct SearchView: View {
    @State private var query = ""
    @State private var results: [Track] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    private let musicService: MusicService = ITunesMusicService()
    @StateObject private var audioPlayer = AudioPlayerService.shared
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.monetBackground.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Custom Search Bar
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.monetSecondary)
                        TextField("Артисты, треки, альбомы", text: $query)
                            .foregroundColor(.white)
                            .disableAutocorrection(true)
                            .onSubmit {
                                performSearch()
                            }
                        
                        if !query.isEmpty {
                            Button(action: {
                                query = ""
                                results = []
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.monetSecondary)
                            }
                        }
                    }
                    .padding(12)
                    .background(Color.monetSurface)
                    .cornerRadius(10)
                    .padding(.horizontal, MonetTheme.padding)
                    .padding(.top, 16)
                    .padding(.bottom, 16)
                    
                    if isLoading {
                        Spacer()
                        ProgressView()
                            .tint(.white)
                        Spacer()
                    } else if let errorMessage = errorMessage {
                        Spacer()
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                            .padding()
                        Spacer()
                    } else if results.isEmpty && !query.isEmpty {
                        Spacer()
                        Text("Ничего не найдено")
                            .foregroundColor(.monetSecondary)
                        Spacer()
                    } else if results.isEmpty {
                        Spacer()
                        VStack(spacing: 16) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 48))
                                .foregroundColor(.monetSecondary.opacity(0.5))
                            Text("Найдите любимую музыку")
                                .font(.system(size: 16))
                                .foregroundColor(.monetSecondary)
                        }
                        Spacer()
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 0) {
                                ForEach(results) { track in
                                    TrackRowView(track: track) {
                                        audioPlayer.play(track: track, queue: results)
                                    }
                                }
                            }
                            .padding(.bottom, 100) // Padding for Mini Player
                        }
                    }
                }
            }
            .navigationTitle("Поиск")
            .navigationBarTitleDisplayMode(.large)
        }
    }
    
    private func performSearch() {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let fetchedResults = try await musicService.search(query: query)
                await MainActor.run {
                    self.results = fetchedResults
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Ошибка загрузки: \(error.localizedDescription)"
                    self.isLoading = false
                }
            }
        }
    }
}
