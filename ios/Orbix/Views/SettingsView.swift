import SwiftUI

struct SettingsView: View {
    let onLogout: () -> Void

    @State private var appVersion: String = ""
    @State private var buildNumber: String = ""
    @State private var serverName: String = ""
    @State private var serverURL: String = ""
    @State private var serverVersion: String = ""
    @State private var username: String = ""
    @State private var isLoading = true

    @State private var serverOnline: Bool?

    @State private var updateCheck: UpdateCheck?
    @State private var isCheckingUpdate = false
    @State private var isDownloading = false
    @State private var downloadProgress: Double = 0

    @EnvironmentObject private var appLock: AppLockService
    @ObservedObject private var creds = CredentialsManager.shared
    @State private var showAddService = false
    @State private var editingCred: ServiceCredential?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    if !isLoading {
                        serverSection
                        securitySection
                        servicesSection
                        updateSection
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 40)
            }
            .background(AppColors.mainBg.ignoresSafeArea())
            .navigationTitle(OrbixStrings.navSettings)
            .sheet(isPresented: $showAddService) {
                AddServiceView(existing: editingCred) { cred in
                    creds.save(cred)
                }
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            }
            .onAppear { loadInfo() }
        }
    }

    // MARK: - Server Section
    private var serverSection: some View {
        VStack(spacing: 16) {
            sectionTitle(OrbixStrings.sectionServer, icon: "server.rack") {
                if let online = serverOnline {
                    HStack(spacing: 4) {
                        Circle().fill(online ? AppColors.success : AppColors.danger).frame(width: 7, height: 7)
                        Text(online ? String(localized: "在线", comment: "Online") : String(localized: "离线", comment: "Offline"))
                            .font(.system(size: 13))
                            .foregroundColor(online ? AppColors.success : AppColors.danger)
                    }
                }
            }

            VStack(spacing: 1) {
                itemRow(icon: "network", label: OrbixStrings.sectionAddress, value: serverURL)
                if !serverVersion.isEmpty {
                    itemRow(icon: "cube.transparent", label: OrbixStrings.miscQBVersion, value: serverVersion)
                }
                itemRow(icon: "person.fill", label: OrbixStrings.sectionUser, value: username)
            }
            .cardBackground()

            Button {
                logout()
            } label: {
                Text(OrbixStrings.btnSwitchServer)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(AppColors.danger)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .cardBackground()
        }
    }

    // MARK: - Security Section
    @ViewBuilder
    private var securitySection: some View {
        if appLock.isDeviceSupported {
            VStack(spacing: 16) {
                sectionTitle(appLock.hasFaceID ? "Face ID" : OrbixStrings.miscBiometric,
                             icon: appLock.hasFaceID ? "faceid" : "touchid")

                VStack(spacing: 1) {
                    HStack {
                        Label(appLock.hasFaceID ? "Face ID" : OrbixStrings.miscBiometric,
                              systemImage: appLock.hasFaceID ? "faceid" : "touchid")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(AppColors.label)
                        Spacer()
                        Toggle("", isOn: $appLock.isEnabled)
                            .tint(AppColors.accent)
                            .labelsHidden()
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 14)

                    if appLock.isEnabled {
                        Text(String(localized: "切到后台 8 秒后自动锁定", comment: "Auto-lock after 8s"))
                            .font(.system(size: 13))
                            .foregroundColor(AppColors.tertiaryLabel)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 20)
                            .padding(.bottom, 14)
                    }
                }
                .cardBackground()
            }
        }
    }

    // MARK: - Services Section
    @ViewBuilder
    private var servicesSection: some View {
        let list = creds.allCredentials
        if !list.isEmpty {
            VStack(spacing: 16) {
                sectionTitle(OrbixStrings.sectionServices, icon: "antenna.radiowaves.left.and.right")

                VStack(spacing: 1) {
                    ForEach(list) { cred in
                        Button {
                            editingCred = cred
                            showAddService = true
                        } label: {
                            serviceRow(cred: cred)
                        }
                        .buttonStyle(.plain)
                    }

                    Button {
                        editingCred = nil
                        showAddService = true
                    } label: {
                        HStack(spacing: 10) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 8).fill(AppColors.accent.opacity(0.12)).frame(width: 32, height: 32)
                                Image(systemName: "plus").font(.system(size: 14, weight: .bold)).foregroundColor(AppColors.accent)
                            }
                            Text(OrbixStrings.navAddService)
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(AppColors.accent)
                            Spacer()
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 14)
                    }
                    .buttonStyle(.plain)
                }
                .cardBackground()
            }
        }
    }

    private func serviceRow(cred: ServiceCredential) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8).fill(serviceColor(cred.kind).opacity(0.12)).frame(width: 32, height: 32)
                Image(systemName: cred.kind.icon).font(.system(size: 15, weight: .medium)).foregroundColor(serviceColor(cred.kind))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(cred.name).font(.system(size: 15, weight: .medium)).foregroundColor(AppColors.label)
                Text("\(cred.host):\(cred.port)").font(.system(size: 12, design: .monospaced)).foregroundColor(AppColors.tertiaryLabel)
            }
            Spacer()
            Image(systemName: "chevron.right").font(.system(size: 12, weight: .medium)).foregroundColor(AppColors.tertiaryLabel)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    private func serviceColor(_ kind: ServiceKind) -> Color {
        switch kind {
        case .qBittorrent: return AppColors.accent
        case .prowlarr: return AppColors.warning
        case .radarr: return Color(hex: "#8B5CF6")
        }
    }

    // MARK: - Update Section
    private var updateSection: some View {
        VStack(spacing: 16) {
            sectionTitle(OrbixStrings.sectionUpdate, icon: "arrow.down.circle") {
                Text("v\(appVersion)")
                    .font(.system(size: 13))
                    .foregroundColor(AppColors.tertiaryLabel)
            }

            VStack(spacing: 1) {
                Button {
                    checkUpdate()
                } label: {
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(updateIconColor.opacity(0.12))
                                .frame(width: 32, height: 32)
                            Image(systemName: updateIconName)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(updateIconColor)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(updateStatusText).font(.system(size: 15, weight: .medium)).foregroundColor(AppColors.label)
                            if let detail = updateStatusDetail {
                                Text(detail).font(.system(size: 12)).foregroundColor(AppColors.tertiaryLabel)
                            }
                        }
                        Spacer()
                        if isCheckingUpdate { ProgressView().scaleEffect(0.8) }
                        else { Image(systemName: "chevron.right").font(.system(size: 12, weight: .medium)).foregroundColor(AppColors.tertiaryLabel) }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 14)
                }
                .buttonStyle(.plain)
                .disabled(isCheckingUpdate)
            }
            .cardBackground()

            if let release = updateCheck?.latest {
                releaseCard(release)
            }

            if isDownloading {
                downloadProgressView
            }
        }
    }

    private var updateIconName: String {
        if isCheckingUpdate { return "arrow.down.circle.dotted" }
        if let check = updateCheck, check.latest != nil { return "star.circle.fill" }
        if updateCheck?.error != nil { return "exclamationmark.circle.fill" }
        if updateCheck != nil { return "checkmark.circle.fill" }
        return "arrow.down.circle"
    }

    private var updateIconColor: Color {
        if let check = updateCheck, check.latest != nil { return AppColors.warning }
        if updateCheck?.error != nil { return AppColors.danger }
        if updateCheck != nil { return AppColors.success }
        return AppColors.accent
    }

    private var updateStatusText: String {
        if isCheckingUpdate { return OrbixStrings.btnCheckUpdate }
        if updateCheck?.latest != nil { return OrbixStrings.miscUpdateAvailable }
        if updateCheck?.error != nil { return OrbixStrings.btnRetry }
        if updateCheck != nil { return OrbixStrings.btnCheckUpdate }
        return OrbixStrings.btnCheckUpdate
    }

    private var updateStatusDetail: String? {
        if isCheckingUpdate { return nil }
        if updateCheck?.latest != nil { return nil }
        if updateCheck?.error != nil { return nil }
        if updateCheck != nil { return OrbixStrings.msgUpToDate }
        return nil
    }

    private func releaseCard(_ release: AppRelease) -> some View {
        VStack(spacing: 14) {
            HStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8).fill(AppColors.warning.opacity(0.12)).frame(width: 32, height: 32)
                    Image(systemName: "sparkles").font(.system(size: 14)).foregroundColor(AppColors.warning)
                }
                Text(release.version).font(.system(size: 17, weight: .bold)).foregroundColor(AppColors.label)
                Spacer()
                if let size = release.ipaSize {
                    Text(formatBytes(size))
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundColor(AppColors.tertiaryLabel)
                        .padding(.horizontal, 10).padding(.vertical, 4)
                        .background(Capsule().fill(AppColors.elevated))
                }
            }

            let cleanNotes = release.notes
                .replacingOccurrences(of: "\\[[^\\]]+\\]\\([^)]+\\)", with: "", options: .regularExpression)
                .replacingOccurrences(of: "https?://\\S+", with: "", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !cleanNotes.isEmpty {
                Text(cleanNotes).font(.system(size: 13)).foregroundColor(AppColors.secondaryLabel).lineLimit(3)
            }

            Button {
                downloadUpdate(release)
            } label: {
                Text(isDownloading ? OrbixStrings.msgDownloadingDot : OrbixStrings.btnDownloadInstall)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(RoundedRectangle(cornerRadius: 12).fill(AppColors.accent))
            }
            .disabled(isDownloading)
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 20).fill(AppColors.card))
    }

    private var downloadProgressView: some View {
        VStack(spacing: 8) {
            GeometryReader { geo in
                Capsule()
                    .fill(AppColors.accent)
                    .frame(width: max(4, geo.size.width * downloadProgress))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Capsule().fill(AppColors.separator))
                    .animation(.easeOut(duration: 0.3), value: downloadProgress)
            }
            .frame(height: 4)
            Text("\(min(99, Int(downloadProgress * 100)))%")
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundColor(AppColors.accent)
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Shared Components
    private func sectionTitle(_ title: String, icon: String, trailing: (() -> some View)? = nil) -> some View {
        HStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 8).fill(AppColors.accent.opacity(0.1)).frame(width: 28, height: 28)
                Image(systemName: icon).font(.system(size: 13, weight: .semibold)).foregroundColor(AppColors.accent)
            }
            Text(title).font(.system(size: 13, weight: .semibold)).foregroundColor(AppColors.secondaryLabel).textCase(.uppercase)
            Spacer()
            if let t = trailing { AnyView(t()) }
        }
        .padding(.leading, 4)
    }

    private func itemRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8).fill(AppColors.elevated).frame(width: 32, height: 32)
                Image(systemName: icon).font(.system(size: 13)).foregroundColor(AppColors.tertiaryLabel)
            }
            Text(label).font(.system(size: 15, weight: .medium)).foregroundColor(AppColors.secondaryLabel)
            Spacer()
            Text(value).font(.system(size: 14, weight: .medium, design: .monospaced)).foregroundColor(AppColors.label)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    // MARK: - Data
    private func loadInfo() {
        Task {
            let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
            let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "0"
            let config = await QBitApi.shared.loadSavedConfig()
            let qbitVersion = try? await QBitApi.shared.getAppVersion()

            let configForTest = config
            let sR = await {
                guard let cfg = configForTest else { return nil as CredentialsManager.TestResult? }
                return await CredentialsManager.testConnection(
                    kind: .qBittorrent, host: cfg.host, port: cfg.port, https: cfg.https,
                    username: cfg.username, password: cfg.password
                )
            }()

            await MainActor.run {
                appVersion = version
                buildNumber = build
                serverName = config?.name ?? "-"
                serverURL = config?.url ?? "-"
                username = config?.username ?? "-"
                serverVersion = qbitVersion ?? ""
                serverOnline = sR?.isSuccess
                isLoading = false
            }
        }
    }

    private func logout() {
        Task {
            await QBitApi.shared.setActiveServer(ServerConfig(
                name: "", host: "", port: 0, username: "", password: "", https: false
            ))
        }
        onLogout()
    }

    private func checkUpdate() {
        isCheckingUpdate = true
        Task {
            let check = await UpdateService.shared.check()
            await MainActor.run {
                updateCheck = check
                isCheckingUpdate = false
            }
        }
    }

    private func downloadUpdate(_ release: AppRelease) {
        isDownloading = true
        downloadProgress = 0

        Task {
            do {
                let url = try await UpdateService.shared.downloadIpa(release) { progress in
                    Task { @MainActor in
                        downloadProgress = progress
                    }
                }
                await MainActor.run {
                    isDownloading = false
                    shareIpa(url)
                }
            } catch {
                await MainActor.run { isDownloading = false }
            }
        }
    }

    private func shareIpa(_ url: URL) {
        guard let win = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let w = win.windows.first, let root = w.rootViewController else { return }
        let vc = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        root.present(vc, animated: true)
    }
}

private struct CardBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(RoundedRectangle(cornerRadius: 16).fill(AppColors.card))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.black.opacity(0.05), lineWidth: 0.5))
    }
}

private extension View {
    func cardBackground() -> some View {
        modifier(CardBackground())
    }
}

#if DEBUG
#Preview {
    SettingsView(onLogout: {})
        .preferredColorScheme(.dark)
}
#endif
