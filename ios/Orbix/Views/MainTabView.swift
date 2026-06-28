import SwiftUI

struct MainTabView: View {
    let initialTab: Int?
    let onLogout: () -> Void

    @State private var selectedTab = 2
    @State private var searchTapCount = 0
    @State private var lastSearchTap: Date = .distantPast
    @State private var showEgg = false

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

                SearchView()
                    .tabItem {
                        Image(systemName: "magnifyingglass")
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
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                            showEgg = true
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            withAnimation { showEgg = false }
                        }
                    }
                }
            }

            if showEgg {
                VStack {
                    Spacer()
                    Text("🎛️ 开发者模式已激活")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(
                            Capsule()
                                .fill(AppColors.accent)
                                .shadow(color: AppColors.accent.opacity(0.4), radius: 10, y: 4)
                        )
                        .padding(.bottom, 100)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .zIndex(10)
            }
        }
    }
}
