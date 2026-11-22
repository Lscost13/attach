import SwiftUI

/// Вход в приложение: выбор провайдера, ключ, модель. Он же — экран настроек.
struct ModelSetupView: View {
    @EnvironmentObject private var models: ModelStore
    @Environment(\.dismiss) private var dismiss

    var isOnboarding: Bool = false

    @State private var key: String = ""
    @State private var model: String = ""
    @State private var baseURL: String = ""

    private var canSave: Bool {
        let hasInput = !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || models.hasKey
        let hasModel = !model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let hasBase = !baseURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return hasInput && hasModel && hasBase
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    if isOnboarding {
                        header
                    }

                    section("Провайдер") { providerGrid }
                    section("Ключ API") { keyField }
                    section("Модель") { modelField }
                    section("Адрес") { baseURLField }

                    checkRow
                    actions
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 40)
            }
            .scrollIndicators(.hidden)
            .background(Color.black)
            .navigationTitle(isOnboarding ? "Подключение" : "Модель")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if !isOnboarding {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Готово") { dismiss() }
                            .tint(.white)
                    }
                }
            }
        }
        .onAppear {
            model = models.model
            baseURL = models.baseURL
            if !models.hasKey {
                baseURL = models.provider.defaultBaseURL
            }
        }
    }

    // MARK: - Блоки

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Подключи модель")
                .font(.largeTitle.weight(.semibold))
                .foregroundStyle(.white)

            Text("Ключ хранится в Keychain и никуда не уходит. Можно выбрать любого провайдера или свой endpoint.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.5))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.bottom, 2)
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title.uppercased())
                .font(.caption2.weight(.semibold))
                .tracking(1.4)
                .foregroundStyle(.white.opacity(0.32))
            content()
        }
    }

    private var providerGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
            ForEach(ProviderKind.allCases) { kind in
                Button {
                    withAnimation(.snappy(duration: 0.22)) {
                        models.select(kind)
                        model = models.model
                        baseURL = models.baseURL
                    }
                } label: {
                    HStack(spacing: 9) {
                        Image(systemName: kind.glyph)
                            .font(.system(size: 16))
                        Text(kind.title)
                            .font(.subheadline.weight(.medium))
                        Spacer(minLength: 0)
                    }
                    .foregroundStyle(models.provider == kind ? .black : .white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 14)
                    .background(
                        models.provider == kind ? Color.white : Color.white.opacity(0.05),
                        in: RoundedRectangle(cornerRadius: 16)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(.white.opacity(models.provider == kind ? 0 : 0.1), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var keyField: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: "key")
                    .font(.system(size: 15))
                    .foregroundStyle(.white.opacity(0.45))
                SecureField(models.hasKey ? "ключ сохранён — можно заменить" : "sk-…", text: $key)
                    .font(.body.monospaced())
                    .foregroundStyle(.white)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }
            .padding(15)
            .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.1), lineWidth: 1))

            Text(models.provider.hint)
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.35))

            if let url = models.provider.consoleURL {
                Link(destination: url) {
                    HStack(spacing: 5) {
                        Text("Где взять ключ")
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.white.opacity(0.8))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.white.opacity(0.06), in: Capsule())
                }
            }
        }
    }

    private var modelField: some View {
        VStack(alignment: .leading, spacing: 10) {
            TextField("имя модели", text: $model)
                .font(.body.monospaced())
                .foregroundStyle(.white)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .padding(15)
                .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 16))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.1), lineWidth: 1))

            if !models.provider.models.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(models.provider.models, id: \.self) { preset in
                            Button {
                                withAnimation(.snappy(duration: 0.18)) { model = preset }
                            } label: {
                                Text(preset)
                                    .font(.footnote.monospaced())
                                    .foregroundStyle(model == preset ? .black : .white.opacity(0.75))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 9)
                                    .background(
                                        model == preset ? Color.white : Color.white.opacity(0.07),
                                        in: Capsule()
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    private var baseURLField: some View {
        TextField("https://…/v1", text: $baseURL)
            .font(.subheadline.monospaced())
            .foregroundStyle(.white)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .keyboardType(.URL)
            .padding(15)
            .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.1), lineWidth: 1))
    }

    @ViewBuilder
    private var checkRow: some View {
        switch models.check {
        case .idle:
            EmptyView()
        case .checking:
            HStack(spacing: 10) {
                ProgressView().tint(.white)
                Text("Проверяю ключ…")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.55))
            }
        case .ok(let message):
            HStack(spacing: 10) {
                Image(systemName: "checkmark.circle.fill")
                Text(message)
            }
            .font(.subheadline.weight(.medium))
            .foregroundStyle(.white)
        case .failed(let message):
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "exclamationmark.triangle")
                Text(message)
            }
            .font(.subheadline)
            .foregroundStyle(.white.opacity(0.6))
        }
    }

    private var actions: some View {
        VStack(spacing: 12) {
            Button {
                Task {
                    models.model = model
                    models.baseURL = baseURL
                    models.save(key: key)
                    key = ""
                    await models.runCheck()
                }
            } label: {
                Text("Проверить ключ")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 17)
                    .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 18))
                    .overlay(RoundedRectangle(cornerRadius: 18).stroke(.white.opacity(0.12), lineWidth: 1))
            }
            .buttonStyle(.plain)

            Button {
                models.model = model
                models.baseURL = baseURL
                models.save(key: key)
                key = ""
                dismiss()
            } label: {
                Text(isOnboarding ? "Сохранить и войти" : "Сохранить")
                    .font(.headline)
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(Color.white, in: RoundedRectangle(cornerRadius: 18))
            }
            .buttonStyle(.plain)
            .disabled(!canSave)
            .opacity(canSave ? 1 : 0.35)

            if models.hasKey && !isOnboarding {
                Button(role: .destructive) {
                    models.removeKey()
                    dismiss()
                } label: {
                    Text("Удалить ключ")
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.45))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.top, 4)
    }
}
