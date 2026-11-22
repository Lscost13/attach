import SwiftUI

// MARK: - Общий каркас экрана

struct Screen<Content: View>: View {
    let kicker: String
    let title: String
    @ViewBuilder var content: () -> Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text(kicker.uppercased())
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(1.6)
                    .foregroundStyle(.white.opacity(0.26))

                Text(title)
                    .font(.system(size: 27, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.top, 8)

                content()
                    .padding(.top, 18)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 80)
        }
        .scrollIndicators(.hidden)
        .background(Color.black)
    }
}

struct Row: View {
    let icon: String
    let title: String
    let subtitle: String
    var trailing: String? = nil

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white)
                Text(subtitle)
                    .font(.system(size: 11.5))
                    .foregroundStyle(.white.opacity(0.44))
            }

            Spacer(minLength: 8)

            if let trailing {
                Text(trailing)
                    .font(.system(size: 10.5, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.26))
            }
        }
        .padding(13)
        .background(.white.opacity(0.035), in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(.white.opacity(0.1), lineWidth: 1))
    }
}

// MARK: - Экраны

struct ChatsView: View {
    var body: some View {
        Screen(kicker: "Чаты", title: "Проекты") {
            VStack(spacing: 8) {
                Row(icon: "folder", title: "Парсер", subtitle: "3 чата · сегодня", trailing: "›")
                Row(icon: "folder", title: "Дом", subtitle: "5 чатов · вчера", trailing: "›")
                Row(icon: "folder", title: "Работа", subtitle: "2 чата · 12 ноя", trailing: "›")
            }
        }
    }
}

struct AppsView: View {
    var body: some View {
        Screen(kicker: "Мини-аппы", title: "Свои штуки") {
            VStack(spacing: 12) {
                Image(systemName: "square.grid.2x2")
                    .font(.system(size: 24))
                    .foregroundStyle(.white.opacity(0.6))
                Text("Пока пусто")
                    .font(.system(size: 16, weight: .semibold))
                Text("Скажи агенту в чате — он соберёт мини-апп и положит сюда.")
                    .font(.system(size: 12.5))
                    .foregroundStyle(.white.opacity(0.44))
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(32)
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(style: StrokeStyle(lineWidth: 1, dash: [5, 5]))
                    .foregroundStyle(.white.opacity(0.16))
            )
        }
    }
}

struct AgentsView: View {
    var body: some View {
        Screen(kicker: "Агенты", title: "Кто работает") {
            VStack(spacing: 8) {
                Row(icon: "sparkle", title: "Основной", subtitle: "Универсальный · deepseek-chat")
                Row(icon: "chevron.left.forwardslash.chevron.right", title: "Кодер", subtitle: "Пишет и правит код")
                Row(icon: "house", title: "Дом", subtitle: "Бытовые задачи и списки")
            }
        }
    }
}

struct TasksView: View {
    var body: some View {
        Screen(kicker: "Панель", title: "Задачи") {
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    Text("В работе 1")
                        .font(.system(size: 10, weight: .semibold))
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .background(.white, in: Capsule())
                        .foregroundStyle(.black)
                    Text("Ждут 1")
                        .font(.system(size: 10, weight: .semibold))
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .overlay(Capsule().stroke(.white.opacity(0.17)))
                        .foregroundStyle(.white.opacity(0.64))
                    Text("Готово 9")
                        .font(.system(size: 10, weight: .semibold))
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .overlay(Capsule().stroke(.white.opacity(0.17)))
                        .foregroundStyle(.white.opacity(0.64))
                    Spacer()
                }
                .padding(.bottom, 6)

                Row(icon: "play.fill", title: "Рефакторинг парсера", subtitle: "Шаг 2 из 3 · 12 мин", trailing: "открыть")
                Row(icon: "checkmark", title: "Смета на электрику", subtitle: "12 позиций", trailing: "14:02")
            }
        }
    }
}

struct ProfileView: View {
    var body: some View {
        Screen(kicker: "Профиль", title: "Максим") {
            VStack(spacing: 8) {
                Row(icon: "key", title: "Модель и ключи", subtitle: "deepseek-chat · Keychain")
                Row(icon: "lock.shield", title: "Разрешения", subtitle: "Файлы, календарь, микрофон")
                Row(icon: "shippingbox", title: "Версия", subtitle: "0.1 · сборка из GitHub Actions")
            }
        }
    }
}
