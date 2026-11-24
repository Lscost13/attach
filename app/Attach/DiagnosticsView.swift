import SwiftUI
import UIKit

/// Экран журнала: отсюда видно, что случилось с ядром и почему приложение упало.
struct DiagnosticsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var text = "Читаю журнал…"
    @State private var copied = false

    var body: some View {
        NavigationStack {
            ScrollView {
                Text(text)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.7))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
            }
            .scrollIndicators(.hidden)
            .background(Color.black)
            .navigationTitle("Журнал")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Готово") { dismiss() }
                        .tint(.white)
                }
                ToolbarItem(placement: .bottomBar) {
                    HStack(spacing: 10) {
                        Button {
                            UIPasteboard.general.string = text
                            copied = true
                        } label: {
                            Text(copied ? "Скопировано" : "Скопировать")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.black)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(.white, in: RoundedRectangle(cornerRadius: 14))
                        }
                        .buttonStyle(.plain)

                        ShareLink(item: text) {
                            Text("Поделиться")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .stroke(.white.opacity(0.12), lineWidth: 1)
                                )
                        }
                    }
                }
            }
        }
        .onAppear { text = Diag.report() }
    }
}

/// Плашка «было падение» — без неё журнал никто не найдёт.
struct CrashNotice: View {
    var onOpen: () -> Void
    var onClose: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.white)

            VStack(alignment: .leading, spacing: 2) {
                Text("Прошлый запуск упал")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white)
                Text("журнал покажет, что случилось")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.5))
            }

            Spacer(minLength: 0)

            Button(action: onOpen) {
                Text("Открыть")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(.white, in: Capsule())
            }
            .buttonStyle(.plain)

            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.4))
                    .padding(6)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(.white.opacity(0.14), lineWidth: 1)
        )
        .padding(.horizontal, 16)
        .padding(.bottom, 74)
    }
}
