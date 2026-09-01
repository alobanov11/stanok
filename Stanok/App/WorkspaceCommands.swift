import StanokKit
import SwiftUI

struct WorkspaceCommands: Commands {

    var body: some Commands {
        CommandGroup(after: .sidebar) {
            Button("Показать/скрыть боковую панель") {
                actions?.toggleSidebar()
            }
            .keyboardShortcut("1", modifiers: .command)
            .disabled(actions == nil)

            Button("Все файлы") {
                actions?.toggleAllFiles()
            }
            .keyboardShortcut("2", modifiers: .command)
            .disabled(actions == nil)

            Button("Изменения") {
                actions?.toggleChangedFiles()
            }
            .keyboardShortcut("3", modifiers: .command)
            .disabled(actions == nil)

            Button("Изменения агентов") {
                actions?.toggleAgentChanges()
            }
            .keyboardShortcut("4", modifiers: .command)
            .disabled(actions == nil)
        }

        CommandGroup(replacing: .newItem) {
            Button("Новая вкладка") {
                actions?.newTerminalTab?()
            }
            .keyboardShortcut("n", modifiers: .command)
            .disabled(actions?.newTerminalTab == nil)
        }

        CommandGroup(before: .saveItem) {
            Button("Закрыть вкладку") {
                actions?.closeTerminalTab?()
            }
            .keyboardShortcut("w", modifiers: .command)
            .disabled(actions?.closeTerminalTab == nil)
        }
    }

    @FocusedValue(\.workspaceCommands)
    private var actions: WorkspaceCommandActions?
}
