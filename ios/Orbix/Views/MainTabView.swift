import SwiftUI

struct MainTabView: View {
    let initialTab: Int?
    let onLogout: () -> Void

    @State private var selectedTab = 2
    @State private var searchTapCount = 0
    @State private var lastSearchTap: Date = .distantPast
    @State private var show141 = false
    @State private var showEggToast = false

    var body: some View {
        ZStack {
            TabView(selection: $selectedTab) {
                TorrentListView()
                    .tabItem {
                        Image(systemName: "square.stack")
                        Text("种子")
                    }
                    .tag(0)

                StatsView()
                    .tabItem {
                        Image(systemName: "chart.bar")
                        Text("传输")
                    }
                    .tag(1)

                Group {
                    if show141 {
                        SearchView()
                    } else {
                        QBitSearchView()
                    }
                }
                .tabItem {
                    Image(systemName: show141 ? "magnifyingglass.circle.fill" : "magnifyingglass")
                    Text("搜索")
                }
                .tag(2)

                SettingsView(onLogout: onLogout)
                    .tabItem {
                        Image(systemName: "gearshape")
                        Text("设置")
                    }
                    .tag(3)
            }
            .tint(AppColors.accent)
            .onAppear {
                if let tab = initialTab {
                    selectedTab = tab
                }
            }
            .onChange(of: selectedTab) { _, newTab in
                if newTab == 2 {
                    let now = Date()
                    if now.timeIntervalSince(lastSearchTap) < 1.5 {
                        searchTapCount += 1
                    } else {
                        searchTapCount = 1
                    }
                    lastSearchTap = now

                    if searchTapCount >= 3 {
                        searchTapCount = 0
                        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                            show141.toggle()
                            showEggToast = true
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
                            withAnimation { showEggToast = false }
                        }
                    }
                }
            }

            if showEggToast {
                VStack {
                    Spacer()
                    Text(show141 ? "🐙 141ppv 搜刮模式" : "🔍 多源聚合搜索")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 10)
                        .background(
                            Capsule()
                                .fill(.ultraThinMaterial)
                                .shadow(color: .black.opacity(0.2), radius: 10, y: 4)
                        )
                        .padding(.bottom, 100)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .zIndex(10)
                .allowsHitTesting(false)
            }
        }
    }
}
