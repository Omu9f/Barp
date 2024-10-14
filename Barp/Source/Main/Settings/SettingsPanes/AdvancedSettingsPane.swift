//
//  AdvancedSettingsPane.swift
//  Ice
//

import SwiftUI

struct AdvancedSettingsPane: View {
    @EnvironmentObject var appState: AppState
    @State private var maxSliderLabelWidth: CGFloat = 0

    private var menuBarManager: MenuBarManager {
        appState.menuBarManager
    }

    private var manager: AdvancedSettingsManager {
        appState.settingsManager.advancedSettingsManager
    }

    private func formattedToSeconds(_ interval: TimeInterval) -> LocalizedStringKey {
        let formatted = interval.formatted()
        return if interval == 1 {
            LocalizedStringKey(formatted + " second")
        } else {
            LocalizedStringKey(formatted + " seconds")
        }
    }

    var body: some View {
        IceForm {
            IceSection {
                hideApplicationMenus
                showSectionDividers
                showAllSectionsOnUserDrag
            }
            IceSection {
                enableAlwaysHiddenSection
                canToggleAlwaysHiddenSection
            }
        }
    }

    @ViewBuilder
    private var hideApplicationMenus: some View {
        Toggle("Hide application menus when showing menu bar items", isOn: manager.bindings.hideApplicationMenus)
            .annotation("Make more room in the menu bar by hiding the left application menus if needed")
    }

    @ViewBuilder
    private var showSectionDividers: some View {
        Toggle("Show section dividers", isOn: manager.bindings.showSectionDividers)
            .annotation {
                HStack(spacing: 2) {
                    Text("Insert divider items")
                    if let nsImage = ControlItemImage.builtin(.chevronLarge).nsImage(for: appState) {
                        HStack(spacing: 0) {
                            Text("(")
                                .font(.body.monospaced().bold())
                            Image(nsImage: nsImage)
                                .padding(.horizontal, -2)
                            Text(")")
                                .font(.body.monospaced().bold())
                        }
                    }
                    Text("between sections")
                }
            }
    }

    @ViewBuilder
    private var enableAlwaysHiddenSection: some View {
        Toggle("Enable always-hidden section", isOn: manager.bindings.enableAlwaysHiddenSection)
    }

    @ViewBuilder
    private var canToggleAlwaysHiddenSection: some View {
        if manager.enableAlwaysHiddenSection {
            Toggle("Always-hidden section can be shown", isOn: manager.bindings.canToggleAlwaysHiddenSection)
                .annotation {
                    if appState.settingsManager.generalSettingsManager.showOnClick {
                        Text("Option + click one of Ice's menu bar items, or inside an empty area of the menu bar to show the section")
                    } else {
                        Text("Option + click one of Ice's menu bar items to show the section")
                    }
                }
        }
    }

    @ViewBuilder
    private var showAllSectionsOnUserDrag: some View {
        Toggle("Show all sections when Command + dragging menu bar items", isOn: manager.bindings.showAllSectionsOnUserDrag)
    }
}

#Preview {
    AdvancedSettingsPane()
        .fixedSize()
        .environmentObject(AppState())
}
