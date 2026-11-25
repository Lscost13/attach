import SwiftUI

/// Экран запуска: ядро поднимается сразу, а человек видит, на каком оно шаге.
struct BootView: View {
    let installer: EngineInstaller
    let core: CoreRuntime

    @State private var spin: Double = 0
    @State private var breathe = false
    @State private var revealed = false

    private enum Stage: Equatable {
        case checking
        case downloading
        case unpacking
        case starting
        case connecting
        case ready
        case failed(String)
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 28) {
                mark

                VStack(spacing: 10) {
                    Text(title)
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(.white)
                        .contentTransition(.opacity)

                    Text(detail)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.45))
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .contentTransition(.opacity)
                }
                .animation(.easeInOut(duration: 0.3), value: stage)

                footer
            }
            .padding(.horizontal, 40)
            .opacity(revealed ? 1 : 0)
        }
        .onAppear {
            withAnimation(.linear(duration: 1.7).repeatForever(autoreverses: false)) {
                spin = 360
            }
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                breathe = true
            }
            withAnimation(.easeOut(duration: 0.5)) { revealed = true }
        }
    }

    // MARK: - Знак

    private var mark: some View {
        ZStack {
            Circle()
                .fill(.white.opacity(0.07))
                .frame(width: 132, height: 132)
                .blur(radius: 26)
                .scaleEffect(breathe ? 1.06 : 0.94)

            Circle()
                .strokeBorder(.white.opacity(0.14), lineWidth: 1)
                .frame(width: 112, height: 112)

            Circle()
                .trim(from: 0, to: isWorking ? 0.24 : 1)
                .stroke(
                    .white.opacity(isWorking ? 0.9 : 0.35),
                    style: StrokeStyle(lineWidth: 2, lineCap: .round)
                )
                .frame(width: 112, height: 112)
                .rotationEffect(.degrees(spin))

            Text("A")
                .font(.system(size: 40, weight: .semibold))
                .foregroundStyle(.white)
        }
        .frame(height: 140)
    }

    private var isWorking: Bool {
        switch stage {
        case .ready, .failed: return false
        default: return true
        }
    }

    // MARK: - Тексты

    private var stage: Stage {
        if installer.phase == .ready, core.phase.isReady { return .ready }

        switch installer.phase {
        case .downloading: return .downloading
        case .unpacking: return .unpacking
        case .failed(let reason): return .failed(reason)
        default: break
        }

        switch core.phase {
        case .ready: return .ready
        case .starting: return .starting
        case .failed(let reason): return .failed(reason)
        case .idle: return .checking
        }
    }

    private var title: String {
        switch stage {
        case .checking: return "Проверяем ядро"
        case .downloading: return "Скачиваем ядро"
        case .unpacking: return "Распаковываем"
        case .starting: return "Запускаем ядро"
        case .connecting: return "Подключаемся"
        case .ready: return "Готово"
        case .failed: return "Ядро не поднялось"
        }
    }

    private var detail: String {
        switch stage {
        case .checking:
            return "DeepSeek Harness живёт внутри приложения"
        case .downloading:
            return "\(installer.receivedText) · останется на телефоне навсегда"
        case .unpacking:
            return installer.unpackText.isEmpty ? "это самый долгий шаг" : installer.unpackText
        case .starting:
            return "поднимаем Node и DSH локально"
        case .connecting:
            return "ждём адрес от движка"
        case .ready:
            return "DeepSeek Harness на связи"
        case .failed(let reason):
            return reason
        }
    }

    // MARK: - Низ

    @ViewBuilder
    private var footer: some View {
        switch stage {
        case .downloading:
            bar(installer.progress)
        case .unpacking:
            bar(installer.unpackProgress)
        case .failed:
            Button {
                installer.retry()
            } label: {
                Text("Повторить")
                    .font(.headline)
                    .foregroundStyle(.black)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 14)
                    .background(.white, in: RoundedRectangle(cornerRadius: 16))
            }
            .buttonStyle(.plain)
            .padding(.top, 8)
        case .ready:
            HStack(spacing: 8) {
                Circle()
                    .fill(.white)
                    .frame(width: 6, height: 6)
                Text("127.0.0.1 · локально")
                    .font(.caption.monospaced())
                    .foregroundStyle(.white.opacity(0.35))
            }
        default:
            HStack(spacing: 6) {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(.white.opacity(breathe ? 0.5 : 0.2))
                        .frame(width: 5, height: 5)
                        .animation(
                            .easeInOut(duration: 0.6)
                            .repeatForever()
                            .delay(Double(index) * 0.15),
                            value: breathe
                        )
                }
            }
            .padding(.top, 4)
        }
    }

    private func bar(_ value: Double) -> some View {
        VStack(spacing: 8) {
            ProgressView(value: min(max(value, 0), 1))
                .tint(.white)
                .frame(width: 200)
            Text("\(Int(min(max(value, 0), 1) * 100))%")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.white.opacity(0.35))
        }
    }
}
