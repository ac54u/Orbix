import SwiftUI

struct SearchView: View {
    @State private var query = ""
    @State private var results: [ScrapedTorrent] = []
    @State private var isLoading = false
    @State private var state: SearchState = .idle
    @State private var bookmarks: [String] = []
    @State private var selectedTorrent: ScrapedTorrent?
    @State private var showMediaViewer = false
    @State private var mediaViewerIndex = 0

    enum SearchState {
        case idle
        case loading
        case results
        case empty
        case error(String)
    }

    @State private var searchTask: Task<Void, Never>?
    @State private var searchIconTapCount = 0
    @State private var showEasterEgg = false

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.groupedBg.ignoresSafeArea()

                switch state {
                case .idle:
                    idleView
                case .loading:
                    VStack {
                        ProgressView()
                            .tint(AppColors.accent)
                        Text("搜索中...")
                            .subtitle()
                            .padding(.top, 12)
                    }
                case .results:
                    resultsGrid
                case .empty:
                    VStack(spacing: 12) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 48))
                            .foregroundColor(AppColors.placeholder)
                        Text("未找到结果")
                            .subtitle()
                    }
                case .error(let msg):
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 48))
                            .foregroundColor(AppColors.danger)
                        Text(msg)
                            .subtitle(AppColors.danger)
                    }
                }
            }
            .navigationTitle("搜索")
            .onAppear { loadBookmarks() }
            .sheet(item: $selectedTorrent) { torrent in
                TorrentDetailSheet(torrent: torrent)
            }
            .fullScreenCover(isPresented: $showEasterEgg) {
                EasterEggView()
            }
            .fullScreenCover(isPresented: $showMediaViewer) {
                if let thumb = selectedTorrent?.thumbnail {
                    MediaViewer(images: [thumb], initialIndex: 0)
                }
            }
            .safeAreaInset(edge: .top, spacing: 0) {
                searchBar
            }
        }
    }

    private var searchBar: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(AppColors.placeholder)
                        .onTapGesture {
                            searchIconTapCount += 1
                            if searchIconTapCount >= 3 {
                                searchIconTapCount = 0
                                showEasterEgg = true
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                searchIconTapCount = 0
                            }
                        }
                    TextField("搜索 torrent...", text: $query)
                        .bodyFont()
                        .autocapitalization(.none)
                        .onChange(of: query) { _ in
                            debounceSearch()
                        }
                    if !query.isEmpty {
                        Button {
                            query = ""
                            results = []
                            state = .idle
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(AppColors.tertiaryLabel)
                        }
                    }
                }
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(AppColors.card)
                )

                Button {
                    loadBookmarks()
                } label: {
                    Image(systemName: bookmarks.isEmpty ? "heart" : "heart.fill")
                        .foregroundColor(AppColors.accent)
                        .font(.title3)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .background(AppColors.groupedBg)
    }

    private var idleView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("浏览热门")
                .sectionHeader()
                .padding(.horizontal, 36)
                .padding(.top, 16)

            if !bookmarks.isEmpty {
                Section("收藏") {
                    // Bookmark list would go here
                }
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var resultsGrid: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 160, maximum: 170))], spacing: 12) {
                ForEach(results) { torrent in
                    TorrentCard(torrent: torrent, isBookmarked: bookmarks.contains(torrent.code))
                        .onTapGesture {
                            selectedTorrent = torrent
                        }
                        .contextMenu {
                            Button {
                                addMagnet(torrent)
                            } label: {
                                Label("添加到队列", systemImage: "square.and.arrow.down")
                            }
                            Button {
                                toggleBookmark(torrent)
                            } label: {
                                Label(
                                    bookmarks.contains(torrent.code) ? "取消收藏" : "收藏",
                                    systemImage: bookmarks.contains(torrent.code) ? "heart.fill" : "heart"
                                )
                            }
                            Button {
                                UIPasteboard.general.string = torrent.magnet
                            } label: {
                                Label("复制 Magnet", systemImage: "doc.on.doc")
                            }
                        }
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)
        }
        .refreshable {
            await search()
        }
    }

    private func debounceSearch() {
        searchTask?.cancel()
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 400_000_000)
            if !Task.isCancelled {
                await search()
            }
        }
    }

    private func search() async {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else {
            await MainActor.run {
                results = []
                state = .idle
            }
            return
        }

        await MainActor.run { state = .loading }

        do {
            let scraped = try await TorrentSearchService.shared.search(query: query)
            await MainActor.run {
                results = scraped
                state = scraped.isEmpty ? .empty : .results
            }
        } catch {
            await MainActor.run { state = .error(error.localizedDescription) }
        }
    }

    private func addMagnet(_ torrent: ScrapedTorrent) {
        Task {
            try? await QBitApi.shared.addMagnet([torrent.magnet])
        }
    }

    private func toggleBookmark(_ torrent: ScrapedTorrent) {
        let isNow = PersistenceService.shared.toggleBookmark(torrent.code)
        loadBookmarks()
    }

    private func loadBookmarks() {
        bookmarks = PersistenceService.shared.loadBookmarks()
    }
}

private struct TorrentCard: View {
    let torrent: ScrapedTorrent
    let isBookmarked: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .bottomLeading) {
                AsyncImage(url: URL(string: torrent.thumbnail ?? "")) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    case .failure, .empty:
                        Rectangle()
                            .fill(AppColors.card)
                            .overlay {
                                Image(systemName: "photo")
                                    .foregroundColor(AppColors.placeholder)
                            }
                    @unknown default:
                        Rectangle().fill(AppColors.card)
                    }
                }
                .frame(height: 120)
                .clipped()

                LinearGradient(
                    colors: [.clear, .black.opacity(0.6)],
                    startPoint: .top,
                    endPoint: .bottom
                )

                HStack {
                    Text(torrent.size)
                        .caption(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 4))
                    Spacer()
                    if isBookmarked {
                        Image(systemName: "heart.fill")
                            .font(.caption2)
                            .foregroundColor(AppColors.accent)
                    }
                }
                .padding(6)

                if !torrent.date.isEmpty {
                    Text(torrent.date)
                        .caption(.white.opacity(0.8))
                        .padding(6)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .offset(y: -24)
                }
            }

            Text(torrent.title)
                .subtitle()
                .lineLimit(2)
                .padding(8)
        }
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(AppColors.card)
        )
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

private struct TorrentDetailSheet: View {
    let torrent: ScrapedTorrent
    @Environment(\.dismiss) private var dismiss

    @State private var translatedDescription: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let thumb = torrent.thumbnail {
                        AsyncImage(url: URL(string: thumb)) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(maxHeight: 250)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            default:
                                Rectangle()
                                    .fill(AppColors.card)
                                    .frame(height: 200)
                            }
                        }
                    }

                    Text(torrent.title)
                        .cardTitle()

                    HStack(spacing: 16) {
                        Label(torrent.size, systemImage: "doc")
                            .caption()
                        Label(torrent.date, systemImage: "calendar")
                            .caption()
                    }

                    if let desc = translatedDescription ?? torrent.description {
                        Text(desc)
                            .subtitle()
                            .textSelection(.enabled)
                    }

                    HStack(spacing: 12) {
                        Button {
                            Task {
                                try? await QBitApi.shared.addMagnet([torrent.magnet])
                                dismiss()
                            }
                        } label: {
                            Label("添加到队列", systemImage: "square.and.arrow.down")
                                .bodyFont(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(
                                    RoundedRectangle(cornerRadius: 14)
                                        .fill(AppColors.accent)
                                )
                        }

                        Button {
                            UIPasteboard.general.string = torrent.magnet
                        } label: {
                            Image(systemName: "doc.on.doc")
                                .font(.title3)
                                .foregroundColor(AppColors.accent)
                                .frame(width: 44, height: 44)
                                .background(
                                    RoundedRectangle(cornerRadius: 14)
                                        .stroke(AppColors.accent, lineWidth: 1)
                                )
                        }
                    }
                    .padding(.top, 8)
                }
                .padding(16)
            }
            .background(AppColors.groupedBg)
            .navigationTitle("详情")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
        }
        .onAppear {
            translate()
        }
    }

    private func translate() {
        guard let desc = torrent.description, !desc.isEmpty else { return }
        Task {
            let translated = try? await TranslateService.shared.toChinese(desc)
            await MainActor.run { translatedDescription = translated }
        }
    }
}

private struct EasterEggView: View {
    @State private var animate = false
    @State private var showText = false
    @State private var particles: [Particle] = []
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            AnimatedBg(animate: animate)

            ForEach(particles) { p in
                Text(p.emoji)
                    .font(.system(size: p.size))
                    .position(p.position)
                    .opacity(p.opacity)
                    .animation(.easeOut(duration: 2).repeatForever(autoreverses: true), value: animate)
            }

            VStack(spacing: 24) {
                Spacer()

                GlowingLogo(size: 100)
                    .scaleEffect(animate ? 1.2 : 0.8)
                    .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: animate)

                if showText {
                    Text("你发现了隐藏彩蛋！")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.white)
                        .transition(.scale.combined(with: .opacity))

                    Text("141ppv 秘密探索者")
                        .font(.headline)
                        .foregroundColor(.white.opacity(0.8))
                        .transition(.opacity)
                }

                Spacer()

                Button {
                    dismiss()
                } label: {
                    Text("返回搜索")
                        .font(.body)
                        .foregroundColor(.white)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 12)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                }
                .padding(.bottom, 60)
            }
        }
        .ignoresSafeArea()
        .onAppear {
            animate = true
            generateParticles()
            withAnimation(.easeOut(duration: 0.8).delay(0.3)) {
                showText = true
            }
        }
    }

    private func generateParticles() {
        let emojis = ["✨", "🌟", "💫", "⭐", "🎯", "🔍", "🎉", "🎊"]
        for _ in 0..<20 {
            let p = Particle(
                id: UUID(),
                emoji: emojis.randomElement()!,
                position: CGPoint(
                    x: CGFloat.random(in: 0...UIScreen.main.bounds.width),
                    y: CGFloat.random(in: 0...UIScreen.main.bounds.height)
                ),
                size: CGFloat.random(in: 16...36),
                opacity: Double.random(in: 0.3...0.9)
            )
            particles.append(p)
        }
    }
}

private struct Particle: Identifiable {
    let id: UUID
    let emoji: String
    let position: CGPoint
    let size: CGFloat
    let opacity: Double
}

private struct AnimatedBg: View {
    let animate: Bool

    var body: some View {
        LinearGradient(
            colors: [AppColors.accent, .purple, AppColors.accentDark, .pink],
            startPoint: animate ? .topLeading : .bottomTrailing,
            endPoint: animate ? .bottomTrailing : .topLeading
        )
        .animation(.easeInOut(duration: 4).repeatForever(autoreverses: true), value: animate)
    }
}
