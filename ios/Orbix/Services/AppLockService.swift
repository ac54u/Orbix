import SwiftUI
import LocalAuthentication

@MainActor
final class AppLockService: ObservableObject {
    static let shared = AppLockService()

    @Published var isLocked: Bool
    @Published var isEnabled: Bool {
        didSet {
            PersistenceService.shared.appLockEnabled = isEnabled
        }
    }

    private var enteredBackgroundAt: Date?

    var isDeviceSupported: Bool {
        LAContext().canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
    }

    var hasFaceID: Bool {
        LAContext().biometryType == .faceID
    }

    private init() {
        let enabled = PersistenceService.shared.appLockEnabled
        isEnabled = enabled
        isLocked = enabled
        observeLifecycle()
    }

    private func observeLifecycle() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(didEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(willEnterForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
    }

    @objc private func didEnterBackground() {
        guard isEnabled else { return }
        enteredBackgroundAt = Date()
    }

    @objc private func willEnterForeground() {
        guard isEnabled else { return }

        if let entered = enteredBackgroundAt, Date().timeIntervalSince(entered) > 8 {
            isLocked = true
            authenticate()
        }
        enteredBackgroundAt = nil
    }

    func authenticate(reason: String = OrbixStrings.lockUnlockReason) {
        guard isEnabled else {
            isLocked = false
            return
        }

        let context = LAContext()
        context.localizedFallbackTitle = OrbixStrings.lockFallbackTitle

        Task { @MainActor in
            do {
                let success = try await context.evaluatePolicy(
                    .deviceOwnerAuthentication,
                    localizedReason: reason
                )
                if success {
                    isLocked = false
                }
            } catch {
                isLocked = true
            }
        }
    }

    func lock() {
        guard isEnabled else { return }
        isLocked = true
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

struct AppLockGate<Content: View>: View {
    @EnvironmentObject private var appLock: AppLockService
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        ZStack {
            content
            if appLock.isLocked {
                LockScreen()
                    .transition(.opacity.animation(.easeInOut(duration: 0.3)))
                    .zIndex(100)
            }
        }
        .animation(.easeInOut(duration: 0.35), value: appLock.isLocked)
    }
}

private struct LockScreen: View {
    @EnvironmentObject private var appLock: AppLockService
    @State private var showFallback = false
    @State private var fallbackPassword = ""
    @State private var logoPulse = false

    private var biometricIcon: String {
        appLock.hasFaceID ? "faceid" : "touchid"
    }

    private var biometricName: String {
        appLock.hasFaceID ? "Face ID" : OrbixStrings.miscBiometric
    }

    var body: some View {
        ZStack {
            AppColors.mainBg.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                logoSection

                Spacer().frame(height: 40)

                if showFallback {
                    fallbackSection
                } else {
                    biometricSection
                }

                Spacer()
            }
            .padding(.horizontal, 40)
        }
    }

    // MARK: - Logo
    private var logoSection: some View {
        VStack(spacing: AppSpacing.lg) {
            GlowingLogo(size: 96)
                .scaleEffect(logoPulse ? 1.04 : 1.0)
                .animation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true), value: logoPulse)
                .onAppear { logoPulse = true }

            VStack(spacing: AppSpacing.xs) {
                Text("Orbix")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundColor(AppColors.label)

                Text(OrbixStrings.lockLocked)
                    .font(.system(size: 15))
                    .foregroundColor(AppColors.tertiaryLabel)
            }
        }
    }

    // MARK: - Biometric
    private var biometricSection: some View {
        VStack(spacing: AppSpacing.lg) {
            Text(biometricName)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(AppColors.secondaryLabel)

            Button {
                appLock.authenticate()
            } label: {
                Image(systemName: biometricIcon)
                    .font(.system(size: 32, weight: .regular))
                    .foregroundColor(AppColors.label)
                    .frame(width: 72, height: 72)
                    .background(
                        Circle()
                            .fill(AppColors.accent)
                            .shadow(color: AppColors.accent.opacity(0.4), radius: 16, x: 0, y: 4)
                    )
            }
            .buttonStyle(ScaleButtonStyle())
            .padding(.top, AppSpacing.sm)

            Text(String(localized: "轻点以验证身份", comment: "Tap to verify identity"))
                .font(.system(size: 13))
                .foregroundColor(AppColors.tertiaryLabel)
                .padding(.top, AppSpacing.xs)

            Button {
                withAnimation(AppMotion.mediumAnim()) {
                    showFallback = true
                }
            } label: {
                Text(String(localized: "使用密码解锁", comment: "Use password to unlock"))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(AppColors.accent)
            }
            .padding(.top, AppSpacing.xl)
        }
    }

    // MARK: - Fallback Password
    private var fallbackSection: some View {
        VStack(spacing: AppSpacing.md) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 28))
                .foregroundColor(AppColors.accent)

            Text(OrbixStrings.lockFallbackTitle)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(AppColors.label)

            SecureField(OrbixStrings.phPassword, text: $fallbackPassword)
                .font(.system(size: 16))
                .foregroundColor(AppColors.label)
                .padding(.horizontal, AppSpacing.lg)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous)
                        .fill(AppColors.elevated)
                )
                .frame(maxWidth: 280)
                .submitLabel(.go)
                .onSubmit { verifyFallbackPassword() }

            HStack(spacing: AppSpacing.md) {
                Button {
                    withAnimation(AppMotion.mediumAnim()) {
                        showFallback = false
                        fallbackPassword = ""
                    }
                } label: {
                    Text(OrbixStrings.btnCancel)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(AppColors.secondaryLabel)
                }

                Button {
                    verifyFallbackPassword()
                } label: {
                    Text(OrbixStrings.btnOK)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(AppColors.label)
                        .padding(.horizontal, AppSpacing.xl)
                        .padding(.vertical, AppSpacing.sm)
                        .background(
                            Capsule()
                                .fill(AppColors.accent)
                        )
                }
                .disabled(fallbackPassword.isEmpty)
                .opacity(fallbackPassword.isEmpty ? 0.5 : 1)
            }
            .padding(.top, AppSpacing.sm)

            Button {
                withAnimation(AppMotion.mediumAnim()) {
                    showFallback = false
                    fallbackPassword = ""
                }
                appLock.authenticate()
            } label: {
                HStack(spacing: AppSpacing.xs) {
                    Image(systemName: biometricIcon)
                        .font(.system(size: 14))
                    Text(biometricName)
                        .font(.system(size: 14))
                }
                .foregroundColor(AppColors.accent)
            }
            .padding(.top, AppSpacing.md)
        }
    }

    private func verifyFallbackPassword() {
        guard !fallbackPassword.isEmpty else { return }
        appLock.authenticate(reason: String(localized: "输入密码以解锁", comment: "Enter password to unlock"))
    }
}
