import SwiftUI

// MARK: - Toast Type

enum ToastType {
    case success, error, warning, info

    var icon: String {
        switch self {
        case .success: return "checkmark.circle.fill"
        case .error:   return "xmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .info:    return "info.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .success: return .green
        case .error:   return .red
        case .warning: return .orange
        case .info:    return .indigo
        }
    }
}

// MARK: - Toast Item

struct ToastItem: Identifiable {
    let id = UUID()
    let message: String
    let type: ToastType
}

// MARK: - Toast Manager

@MainActor
final class ToastManager: ObservableObject {
    nonisolated(unsafe) static let shared = ToastManager()
    @Published var toasts: [ToastItem] = []

    func show(_ message: String, type: ToastType = .success) {
        let toast = ToastItem(message: message, type: type)
        withAnimation(.spring(response: 0.3)) {
            toasts.append(toast)
            while toasts.count > 3 { toasts.removeFirst() }
        }
        Task {
            try? await Task.sleep(for: .seconds(3))
            withAnimation(.easeOut(duration: 0.2)) {
                guard let index = toasts.firstIndex(where: { $0.id == toast.id }) else { return }
                toasts.remove(at: index)
            }
        }
    }
}

// MARK: - Toast Overlay

struct ToastOverlay: View {
    @StateObject var manager = ToastManager.shared

    var body: some View {
        VStack(spacing: 6) {
            Spacer()
            ForEach(manager.toasts) { toast in
                HStack(spacing: 8) {
                    Image(systemName: toast.type.icon)
                        .font(.caption)
                    Text(toast.message)
                        .font(.caption.bold())
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(toast.type.color)
                .clipShape(Capsule())
                .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .padding(.bottom, 80)
        .allowsHitTesting(false)
    }
}
