import SwiftUI

/// Настройки: то, что не влезло на главный экран профиля.
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("profileName") private var name = "Максим"
    @FocusState private var nameFocused: Bool

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    group("Профиль") {
                        HStack(spacing: 12) {
                            Text("Имя")
                                .font(.subheadline)
                                .foregroundStyle(.white)
                            Spacer(minLength: 12)
                            TextField("Имя", text: $name)
                                .font(.subheadline)
                                .foregroundStyle(.white)
                                .multilineTextAlignment(.trailing)
                                .textInputAutocapitalization(.words)
                                .focused($nameFocused)
                        }
                    }

                    group("Оформление") {
                        row("Тема", "чёрная")
                        row("Акцент", "белый")
                    }

                    group("Разрешения") {
                        row("Файлы", "включено")
                        row("Календарь", "включено")
                        row("Фото", "выключено")
                        row("Микрофон", "включено")
                    }

                    group("О приложении") {
                        row("Версия", "0.1")
                        row("Сборка", "GitHub Actions")
                        row("Репозиторий", "Lscost13/attach")
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 40)
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)
            .background(Color.black)
            .navigationTitle("Настройки")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Готово") { dismiss() }
                        .tint(.white)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Готово") { nameFocused = false }
                }
            }
        }
    }

    private func group<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title.uppercased())
                .font(.caption2.weight(.semibold))
                .tracking(1.4)
                .foregroundStyle(.white.opacity(0.32))

            VStack(alignment: .leading, spacing: 0) {
                content()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 4)
            .background(.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 18))
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(.white.opacity(0.1), lineWidth: 1)
            )
        }
    }

    private func row(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.white)
            Spacer()
            Text(value)
                .font(.footnote.monospaced())
                .foregroundStyle(.white.opacity(0.45))
        }
        .padding(.vertical, 12)
    }
}
