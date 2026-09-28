import SwiftUI

struct SearchView: View {
    @State private var query = ""
    @State private var results: [Track] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var searchTask: Task<Void, Never>? = nil
    
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
                            .onChange(of: query) { oldQuery, newQuery in
                                debounceSearch()
                            }
                            .onSubmit {
                                performSearch()
                            }
                        
                        if !query.isEmpty {
                            Button(action: {
                                query = ""
                                results = []
                                searchTask?.cancel()
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
                        Text("Ждем завершения ввода...")
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
    
    private func debounceSearch() {
        searchTask?.cancel()
        
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else {
            results = []
            return
        }
        
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 600_000_000) // 0.6s debounce
            guard !Task.isCancelled else { return }
            performSearch()
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
                    if fetchedResults.isEmpty {
                        self.errorMessage = "По запросу «\(query)» ничего не найдено"
                    }
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription.isEmpty ? "Не удалось выполнить поиск. Попробуйте ещё раз." : error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }
}
