import SwiftUI

struct QBitSearchView: View {
    @State private var query = ""
    @State private var plugins: [SearchPlugin] = []
    @State private var results: [SearchResult] = []
    @State private var selectedPlugins: Set<String> = ["all"]
    @State private var searchId: Int?
    @State private var status: String?
    @State private var isLoading = false
    @State private var searchTask: Task<Void, Never>?

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.mainBg.ignoresSafeArea()

                VStack(spacing: 0) {
                    pluginBar
                        .padding(.vertical, 8)

                    if isLoading && results.isEmpty {
                        VStack(spacing: 16) {
                            Spacer()
                            ProgressView()
                                .tint(AppColors.accent)
                            Text("正在搜索...")
                                .font(.system(size: 14))
                                .foregroundColor(AppColors.secondaryLabel)
                            Spacer()
                        }
                    } else if !query.isEmpty && results.isEmpty && !isLoading {
                        VStack(spacing: 12) {
                            Spacer()
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 40))
                                .foregroundColor(AppColors.placeholder)
                            Text("没有找到结果")
                                .foregroundColor(AppColors.secondaryLabel)
                            Spacer()
                        }
                    } else {
                        resultsList
                    }
                }
            }
            .navigationTitle("搜索")
            .searchable(text: $query, placement: .automatic, prompt: "搜索种子...")
            .onChange(of: query) { _, _ in debounceSearch() }
            .onAppear { loadPlugins() }
        }
    }

    // MARK: - Plugin Bar
    private var pluginBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                pluginChip("all", label: "所有插件")

                ForEach(plugins) { plugin in
                    if plugin.enabled {
                        pluginChip(plugin.id, label: plugin.name)
                    }
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private func pluginChip(_ id: String, label: String) -> some View {
        let selected = selectedPlugins.contains(id)
        return Button {
            let impact = UIImpactFeedbackGenerator(style: .light)
            impact.impactOccurred()
            if id == "all" {
                selectedPlugins = ["all"]
            } else {
                selectedPlugins.remove("all")
                if selected { selectedPlugins.remove(id) } else { selectedPlugins.insert(id) }
            }
        } label: {
            Text(label)
                .font(.system(size: 13, weight: selected ? .semibold : .regular))
                .foregroundColor(selected ? .white : AppColors.secondaryLabel)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(selected ? AppColors.accent : AppColors.elevated)
                )
        }
    }

    // MARK: - Results List
    private var resultsList: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                if !results.isEmpty {
                    HStack {
                        Text("\(results.count) 条结果")
                            .font(.system(size: 13))
                            .foregroundColor(AppColors.secondaryLabel)
                        Spacer()
                        if status == "Running" {
                            HStack(spacing: 4) {
                                ProgressView()
                                    .scaleEffect(0.6)
                                    .tint(AppColors.accent)
                                Text("搜索中...")
                                    .font(.system(size: 12))
                                    .foregroundColor(AppColors.tertiaryLabel)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 4)
                }

                ForEach(results) { item in
                    resultCard(item)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }

    private func resultCard(_ item: SearchResult) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(item.fileName)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(AppColors.label)
                .lineLimit(2)

            HStack(spacing: 12) {
                Label(formatBytes(Int64(item.fileSize)), systemImage: "doc")
                    .font(.system(size: 12))
                    .foregroundColor(AppColors.secondaryLabel)

                Label("\(item.nbSeeders)", systemImage: "arrow.up.circle")
                    .font(.system(size: 12))
                    .foregroundColor(AppColors.success)

                Label("\(item.nbLeechers)", systemImage: "arrow.down.circle")
                    .font(.system(size: 12))
                    .foregroundColor(AppColors.danger)

                Spacer()

                Button {
                    Task {
                        try? await QBitApi.shared.addMagnet([item.descr])
                        let generator = UINotificationFeedbackGenerator()
                        generator.notificationOccurred(.success)
                    }
                } label: {
                    Image(systemName: "arrow.down.to.line")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(6)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(AppColors.accent)
                        )
                }
            }

            if !item.siteUrl.isEmpty {
                Text(item.siteUrl)
                    .font(.system(size: 11))
                    .foregroundColor(AppColors.tertiaryLabel)
                    .lineLimit(1)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(AppColors.card)
        )
    }

    // MARK: - Search Logic
    private func loadPlugins() {
        Task {
            if let list = try? await QBitApi.shared.getSearchPlugins() {
                await MainActor.run { plugins = list }
            }
        }
    }

    private func debounceSearch() {
        searchTask?.cancel()
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else {
            searchId = nil
            results = []
            isLoading = false
            return
        }
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 500_000_000)
            guard !Task.isCancelled else { return }
            await runSearch()
        }
    }

    private func runSearch() async {
        await MainActor.run { isLoading = true; results = [] }
        do {
            let pList = selectedPlugins.contains("all")
                ? ["all"]
                : Array(selectedPlugins)
            guard let id = try await QBitApi.shared.startSearch(pattern: query, plugins: pList) else {
                await MainActor.run { isLoading = false }
                return
            }
            await MainActor.run { searchId = id }

            // Poll until done
            var attempts = 0
            while attempts < 30 {
                try await Task.sleep(nanoseconds: 1_000_000_000)
                guard !Task.isCancelled else { return }
                attempts += 1
                if let s = try? await QBitApi.shared.getSearchStatus(id: id) {
                    let st = s["status"] as? String ?? ""
                    await MainActor.run { status = st }
                    if st == "Stopped" { break }
                }
            }

            let items = try await QBitApi.shared.getSearchResults(id: id)
            await MainActor.run {
                results = items.sorted { $0.nbSeeders > $1.nbSeeders }
                isLoading = false
            }
        } catch {
            await MainActor.run { isLoading = false }
        }
    }
}
