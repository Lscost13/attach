import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var models: ModelStore
    @StateObject private var core = CoreRuntime.shared

    @AppStorage("profileName") private var name = "Максим"

    @State private var showSetup = false
    @State private var showSettings = false
    @State private var safari: SafariTarget?
    @State private var account: DSHAccount?
    @State private var signingIn = false
    @State private var loginError: String?

    @State private var storage: CoreStorage.Report?
    @State private var balance: String?
    @State private var latestBuild: String?
    @State private var availableBuild: String?
    @State private var showJournal = false
    @State private var crashed = false
    @Environment(\.openURL) private var openURL

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    banner
                    header
                    VStack(spacing: 12) {
                        connectionCard
                        coreCard
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 24)
                }
                .padding(.bottom, 110)
            }
            .scrollIndicators(.hidden)
            .background(Color.black)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                            .font(.system(size: 17, weight: .medium))
                    }
                    .tint(.white)
                }
                ToolbarItem(placement: .principal) { EmptyView() }
            }
            .sheet(isPresented: $showSetup) { ModelSetupView() }
            .sheet(isPresented: $showSettings) { SettingsView() }
            .sheet(isPresented: $showJournal) { DiagnosticsView() }
            .sheet(item: $safari) { target in
                SafariView(url: target.url)
                    .ignoresSafeArea()
            }
            .task {
                crashed = Diag.crashedLastRun || Diag.hasCrash
                storage = await CoreStorage.measure()
                account = await loadAccount()
                if models.hasKey, models.provider == .deepseek {
                    balance = await models.fetchBalance()
                }
            }
        }
    }

    // MARK: Баннер и шапка

    private var banner: some View {
        ZStack(alignment: .bottom) {
            LinearGradient(
                colors: [.white.opacity(0.16), .white.opacity(0.03), .clear],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .frame(height: 168)
            .overlay(alignment: .topLeading) {
                Circle()
                    .fill(.white.opacity(0.12))
                    .frame(width: 220, height: 220)
                    .blur(radius: 60)
                    .offset(x: -40, y: -80)
            }
            .overlay(alignment: .topTrailing) {
                Circle()
                    .fill(.white.opacity(0.07))
                    .frame(width: 180, height: 180)
                    .blur(radius: 50)
                    .offset(x: 40, y: -40)
            }
            .clipped()
        }
        .frame(height: 168)
    }

    private var header: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(Color.black)
                    .frame(width: 96, height: 96)
                Circle()
                    .strokeBorder(.white.opacity(0.22), lineWidth: 1)
                    .frame(width: 96, height: 96)
                Text(initials)
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .offset(y: -46)
            .padding(.bottom, -40)

            Text(name.isEmpty ? "Без имени" : name)
                .font(.title2.weight(.semibold))
                .foregroundStyle(.white)

            Text(models.hasKey ? "\(models.provider.title) · \(models.model)" : "модель не подключена")
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.45))
        }
    }

    private var initials: String {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard let first = trimmed.first else { return "?" }
        return String(first).uppercased()
    }

    // MARK: Подключение

    private var connectionCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Подключение")
                    .font(.headline)
                    .foregroundStyle(.white)
                Spacer()
                Circle()
                    .fill(models.hasKey ? Color.white : Color.white.opacity(0.3))
                    .frame(width: 7, height: 7)
            }

            if account?.signedIn == true {
                Text("Вошёл в аккаунт DeepSeek — движок использует его модель.")
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.5))
                    .fixedSize(horizontal: false, vertical: true)
            } else if models.hasKey {
                HStack(spacing: 6) {
                    Text("ключ сохранён")
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.5))
                    if let balance {
                        Text("·")
                            .foregroundStyle(.white.opacity(0.3))
                        Text("баланс \(balance)")
                            .font(.footnote.monospaced())
                            .foregroundStyle(.white)
                    }
                }
            } else {
                Text("Войди в DeepSeek или добавь ключ провайдера — движок начнёт отвечать в чате.")
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.5))
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let loginError {
                Text(loginError)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.45))
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 10) {
                Button {
                    showSetup = true
                } label: {
                    Text(models.hasKey ? "Сменить ключ" : "API-ключ")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(.white, in: RoundedRectangle(cornerRadius: 14))
                }
                .buttonStyle(.plain)

                Button {
                    startSignIn()
                } label: {
                    Text(account?.signedIn == true ? "Аккаунт DeepSeek" : (signingIn ? "Открываю…" : "Войти в DeepSeek"))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 14))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(.white.opacity(0.12), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .disabled(signingIn || account?.signedIn == true)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 22))
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .stroke(.white.opacity(0.1), lineWidth: 1)
        )
    }

    // MARK: Ядро

    private var coreCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Ядро")
                    .font(.headline)
                    .foregroundStyle(.white)
                Spacer()
                Text(coreTitle)
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.5))
            }

            HStack(alignment: .firstTextBaseline) {
                Text(storage?.totalText ?? "…")
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(.white)
                Text("на диске")
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.4))
                Spacer()
            }

            VStack(spacing: 10) {
                metricRow("движок", storage?.engineText ?? "…")
                metricRow("данные и сессии", storage?.dataText ?? "…")
                metricRow("Node", "24.20 · встроен")
                metricRow("DSH", "0.2.2 · встроен")
                metricRow("сборка", BuildInfo.number)
                metricRow("Python", "не подключён")
            }

            Divider().overlay(.white.opacity(0.1))

            Button {
                Task {
                    latestBuild = await UpdateChecker.latestCommit()
                    if let release = await UpdateChecker.latestRelease() {
                        availableBuild = release.number > BuildInfo.numeric ? release.tag : nil
                    }
                }
            } label: {
                HStack {
                    Text("Проверить обновления")
                        .font(.subheadline.weight(.medium))
                    Spacer()
                    if let availableBuild {
                        Text("есть \(availableBuild)")
                            .font(.caption.monospaced())
                    } else if let latestBuild {
                        Text(latestBuild)
                            .font(.caption.monospaced())
                            .foregroundStyle(.white.opacity(0.5))
                    } else {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 13, weight: .semibold))
                    }
                }
                .foregroundStyle(.white)
                .padding(.vertical, 6)
            }
            .buttonStyle(.plain)

            if availableBuild != nil, let page = BuildInfo.installPage {
                Button {
                    openURL(page)
                } label: {
                    Text("Установить новую сборку")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(.white, in: RoundedRectangle(cornerRadius: 14))
                }
                .buttonStyle(.plain)
            }

            Divider().overlay(.white.opacity(0.1))

            Button {
                showJournal = true
            } label: {
                HStack(spacing: 8) {
                    Text("Журнал")
                        .font(.subheadline.weight(.medium))
                    if crashed {
                        Text("было падение")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.5))
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.3))
                }
                .foregroundStyle(.white)
                .padding(.vertical, 6)
            }
            .buttonStyle(.plain)

            Text("Node и Python компилируются в приложение — обновляются вместе со сборкой, отдельно скачать нельзя.")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.35))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 22))
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .stroke(.white.opacity(0.1), lineWidth: 1)
        )
    }

    private var coreTitle: String {
        switch core.phase {
        case .ready: return "на связи"
        case .starting: return "запускается…"
        case .connecting: return "подключается…"
        case .failed: return "не поднялось"
        case .idle: return "не запущено"
        }
    }

    private func metricRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.5))
            Spacer()
            Text(value)
                .font(.footnote.monospaced())
                .foregroundStyle(.white.opacity(0.85))
        }
    }

    // MARK: Вход в DeepSeek

    private func makeClient() async throws -> DSHClient {
        try await EngineBridge.client()
    }

    private func loadAccount() async -> DSHAccount? {
        try? await makeClient().accountState()
    }

    private func startSignIn() {
        guard !signingIn else { return }
        signingIn = true
        loginError = nil

        Task { @MainActor in
            do {
                let client = try await makeClient()
                var state = try await client.accountState()

                if !state.signedIn && state.authorizeURL == nil {
                    state = try await client.startSignIn()
                }

                for _ in 0..<80 {
                    account = state
                    if state.signedIn { break }

                    if safari == nil,
                       let raw = state.authorizeURL,
                       let url = URL(string: raw) {
                        safari = SafariTarget(url: url)
                    }

                    try? await Task.sleep(nanoseconds: 1_500_000_000)
                    state = try await client.accountState()
                }

                account = state
                safari = nil
                if !state.signedIn {
                    loginError = "Вход не завершился. Попробуй ещё раз."
                }
            } catch {
                loginError = error.localizedDescription
            }
            signingIn = false
        }
    }
}
