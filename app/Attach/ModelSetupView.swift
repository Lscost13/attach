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
                VStack(alignment: .leading, spacing: 22) {
                    if isOnboarding {
                        header
                    }

                    section("Провайдер") {
                        providerGrid
                    }

                    section("Ключ API") {
                        keyField
                    }

                    section("Модель") {
                        modelField
                    }

                    if models.provider == .custom || !baseURL.isEmpty {
                        section("Адрес") {
                            baseURLField
                        }
                    }

                    checkRow

                    actions
                }
                .padding(20)
                .padding(.bottom, 30)
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
        VStack(alignment: .leading, spacing: 8) {
            Text("Attach")
                .font(.system(size: 11, weight: .semibold))
                .tracking(2)
                .foregroundStyle(.white.opacity(0.3))

            Text("Подключи модель")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(.white)

            Text("Ключ хранится в Keychain и никуда не уходит. Можно выбрать любого провайдера или свой endpoint.")
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.45))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.bottom, 4)
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .tracking(1.4)
                .foregroundStyle(.white.opacity(0.28))
            content()
        }
    }

    private var providerGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
            ForEach(ProviderKind.allCases) { kind in
                Button {
                    withAnimation(.snappy(duration: 0.22)) {
                        models.select(kind)
                        model = models.model
                        baseURL = models.baseURL
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: kind.glyph)
                            .font(.system(size: 14))
                        Text(kind.title)
                            .font(.system(size: 13, weight: .medium))
                        Spacer(minLength: 0)
                    }
                    .foregroundStyle(models.provider == kind ? .black : .white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 11)
                    .background(
                        models.provider == kind ? Color.white : Color.white.opacity(0.05),
                        in: RoundedRectangle(cornerRadius: 14)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(.white.opacity(models.provider == kind ? 0 : 0.1), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var keyField: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "key")
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.4))
                SecureField(models.hasKey ? "ключ сохранён — можно заменить" : "sk-…", text: $key)
                    .font(.system(size: 14, design: .monospaced))
                    .foregroundStyle(.white)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }
            .padding(13)
            .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(.white.opacity(0.1), lineWidth: 1))

            Text(models.provider.hint)
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.3))
        }
    }

    private var modelField: some View {
        VStack(alignment: .leading, spacing: 10) {
            TextField("имя модели", text: $model)
                .font(.system(size: 14, design: .monospaced))
                .foregroundStyle(.white)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .padding(13)
                .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(.white.opacity(0.1), lineWidth: 1))

            if !models.provider.models.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(models.provider.models, id: \.self) { preset in
                            Button {
                                withAnimation(.snappy(duration: 0.18)) { model = preset }
                            } label: {
                                Text(preset)
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundStyle(model == preset ? .black : .white.opacity(0.7))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 7)
                                    .background(
                                        model == preset ? Color.white : Color.white.opacity(0.06),
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
            .font(.system(size: 13, design: .monospaced))
            .foregroundStyle(.white)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .keyboardType(.URL)
            .padding(13)
            .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(.white.opacity(0.1), lineWidth: 1))
    }

    @ViewBuilder
    private var checkRow: some View {
        switch models.check {
        case .idle:
            EmptyView()
        case .checking:
            HStack(spacing: 8) {
                ProgressView().tint(.white)
                Text("Проверяю ключ…")
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.5))
            }
        case .ok(let message):
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                Text(message)
            }
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(.white)
        case .failed(let message):
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle")
                Text(message)
            }
            .font(.system(size: 12))
            .foregroundStyle(.white.opacity(0.6))
        }
    }

    private var actions: some View {
        VStack(spacing: 10) {
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
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 16))
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.12), lineWidth: 1))
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
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(Color.white, in: RoundedRectangle(cornerRadius: 16))
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
                        .font(.system(size: 12.5))
                        .foregroundStyle(.white.opacity(0.45))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.top, 6)
    }
}
