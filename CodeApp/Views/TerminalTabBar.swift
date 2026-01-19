//
//  TerminalTabBar.swift
//  Code
//
//  Created by Thales Matheus Mendonça Santos - January 2026
//

import SwiftUI

private enum TerminalTabBarConstants {
    static let tabBarWidth: CGFloat = 50
    static let rowHeight: CGFloat = 36
    static let iconSize: CGFloat = 14
    static let activeIndicatorWidth: CGFloat = 2
}

struct TerminalTabBar: View {
    @EnvironmentObject var App: MainApp

    var body: some View {
        VStack(spacing: 0) {
            // Terminal list
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: 0) {
                    ForEach(App.terminalManager.terminals) { terminal in
                        TerminalTabRow(
                            terminal: terminal,
                            isActive: terminal.id == App.terminalManager.activeTerminalId,
                            canClose: App.terminalManager.terminals.count > 1,
                            onSelect: {
                                App.terminalManager.setActiveTerminal(id: terminal.id)
                            },
                            onClose: {
                                App.terminalManager.closeTerminal(id: terminal.id)
                            }
                        )
                    }
                }
            }
        }
        .frame(width: TerminalTabBarConstants.tabBarWidth)
        .background(Color(id: "sideBar.background"))
    }
}

struct TerminalTabRow: View {
    @EnvironmentObject var App: MainApp

    let terminal: TerminalInstance
    let isActive: Bool
    let canClose: Bool
    let onSelect: () -> Void
    let onClose: () -> Void

    @State private var showingKillConfirmation = false

    private var isTerminalBusy: Bool {
        App.terminalManager.isTerminalBusy(id: terminal.id)
    }

    private var accessibilityLabel: String {
        let activeLabel = NSLocalizedString(
            "Active",
            comment: "Accessibility label for active terminal"
        )
        let runningLabel = NSLocalizedString(
            "Running",
            comment: "Accessibility label for running terminal"
        )
        var parts = [terminal.name]
        if isActive {
            parts.append(activeLabel)
        }
        if isTerminalBusy {
            parts.append(runningLabel)
        }
        return parts.joined(separator: ", ")
    }

    var body: some View {
        HStack(spacing: 0) {
            Spacer()
            // Icon
            Image(systemName: "terminal")
                .font(.system(size: TerminalTabBarConstants.iconSize))
                .foregroundColor(isActive ? Color(id: "list.activeSelectionForeground") : Color(id: "foreground"))
                .frame(width: 20, height: 20)
            Spacer()
        }
        .frame(height: TerminalTabBarConstants.rowHeight)
        .overlay(
            // Left border indicator for active tab (VS Code style)
            HStack {
                if isActive {
                    Rectangle()
                        .fill(Color.accentColor)
                        .frame(width: TerminalTabBarConstants.activeIndicatorWidth)
                }
                Spacer()
            }
        )
        .contentShape(Rectangle())
        .onTapGesture {
            onSelect()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityAddTraits(isActive ? [.isSelected, .isButton] : [.isButton])
        .accessibilityHint(NSLocalizedString("Double tap to switch to this terminal", comment: "Accessibility hint for terminal tab"))
        .contextMenu {
            if canClose {
                Button(NSLocalizedString("Kill Terminal", comment: ""), role: .destructive) {
                    if isTerminalBusy {
                        showingKillConfirmation = true
                    } else {
                        onClose()
                    }
                }
            }
        }
        .alert(
            NSLocalizedString("Kill Terminal?", comment: ""),
            isPresented: $showingKillConfirmation
        ) {
            Button(NSLocalizedString("Cancel", comment: ""), role: .cancel) {}
            Button(NSLocalizedString("Kill", comment: ""), role: .destructive) {
                onClose()
            }
        } message: {
            Text(NSLocalizedString("This terminal has a running process. Are you sure you want to kill it?", comment: ""))
        }
    }
}
