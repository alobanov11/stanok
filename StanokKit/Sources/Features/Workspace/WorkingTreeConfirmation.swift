import SwiftUI

struct WorkingTreeConfirmation: ViewModifier {

    private var isConfirming: Binding<Bool> {
        Binding(get: { action != nil }, set: { if !$0 { action = nil } })
    }

    private var isFailing: Binding<Bool> {
        Binding(get: { failure != nil }, set: { if !$0 { failure = nil } })
    }

    @Binding
    var action: WorkingTreeAction?

    @Binding
    var failure: String?

    let perform: (WorkingTreeAction) async -> Void

    func body(content: Content) -> some View {
        content
            .confirmationDialog(
                action?.title ?? "",
                isPresented: isConfirming,
                presenting: action
            ) { pending in
                Button("Выполнить", role: pending.isDestructive ? .destructive : nil) {
                    Task { await perform(pending) }
                }

                Button("Отмена", role: .cancel) {}
            } message: { pending in
                Text(pending.message)
            }
            .alert("Не получилось", isPresented: isFailing, presenting: failure) { _ in
                Button("Ясно", role: .cancel) {}
            } message: { message in
                Text(message)
            }
    }
}
