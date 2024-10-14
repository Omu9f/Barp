//
//  GeneralSettingsPane.swift
//  Ice
//

import LaunchAtLogin
import SwiftUI

struct GeneralSettingsPane: View {
    @EnvironmentObject var appState: AppState
    @State private var isImportingCustomIceIcon = false
    @State private var isPresentingError = false
    @State private var presentedError: LocalizedErrorWrapper?
    @State private var isApplyingOffset = false
    @State private var tempItemSpacingOffset: CGFloat = 0 // Temporary state for the slider

    private var manager: GeneralSettingsManager {
        appState.settingsManager.generalSettingsManager
    }

    private var itemSpacingOffset: LocalizedStringKey {
        localizedOffsetString(for: manager.itemSpacingOffset)
    }

    private func localizedOffsetString(for offset: CGFloat) -> LocalizedStringKey {
        switch offset {
        case -16:
            return LocalizedStringKey("none")
        case 0:
            return LocalizedStringKey("default")
        case 16:
            return LocalizedStringKey("max")
        default:
            return LocalizedStringKey(offset.formatted())
        }
    }

    private var rehideIntervalKey: LocalizedStringKey {
        let formatted = manager.rehideInterval.formatted()
        if manager.rehideInterval == 1 {
            return LocalizedStringKey(formatted + " second")
        } else {
            return LocalizedStringKey(formatted + " seconds")
        }
    }

    private var hasSpacingSliderValueChanged: Bool {
        tempItemSpacingOffset != manager.itemSpacingOffset
    }

    private var isActualOffsetDifferentFromDefault: Bool {
        manager.itemSpacingOffset != 0
    }

    var body: some View {
        IceForm {
            IceSection {
                launchAtLogin
            }
            IceSection {
                iceIconOptions
            }
            IceSection {
                iceBarOptions
            }
            IceSection {
                showOnClick
                showOnHover
                showOnScroll
            }
        }
        .alert(isPresented: $isPresentingError, error: presentedError) {
            Button("OK") {
                presentedError = nil
                isPresentingError = false
            }
        }
    }

    @ViewBuilder
    private var launchAtLogin: some View {
        LaunchAtLogin.Toggle()
    }

    @ViewBuilder
    private func menuItem(for imageSet: ControlItemImageSet) -> some View {
        Label {
            Text(imageSet.name.rawValue)
        } icon: {
            if let nsImage = imageSet.hidden.nsImage(for: appState) {
                switch imageSet.name {
                case .custom:
                    Image(size: CGSize(width: 18, height: 18)) { context in
                        context.draw(
                            Image(nsImage: nsImage),
                            in: context.clipBoundingRect
                        )
                    }
                default:
                    Image(nsImage: nsImage)
                }
            }
        }
        .iceMenuItemAction {
            manager.iceIcon = imageSet
        }
    }

    @ViewBuilder
    private var iceIconOptions: some View {
        Toggle("Show Barp icon", isOn: manager.bindings.showIceIcon)
            .annotation {
                if !manager.showIceIcon {
                    Text("You can still access Ice's settings by right-clicking an empty area in the menu bar")
                }
            }
        if manager.showIceIcon {
            IceMenu("Barp icon") {
                ForEach(ControlItemImageSet.userSelectableIceIcons) { imageSet in
                    menuItem(for: imageSet)
                }
                if let lastCustomIceIcon = manager.lastCustomIceIcon {
                    menuItem(for: lastCustomIceIcon)
                }
                Divider()
                Text("Choose image…")
                    .iceMenuItemAction {
                        isImportingCustomIceIcon = true
                    }
            } title: {
                menuItem(for: manager.iceIcon)
            }
            .annotation("Choose a custom icon to show in the menu bar")
            .fileImporter(
                isPresented: $isImportingCustomIceIcon,
                allowedContentTypes: [.image]
            ) { result in
                do {
                    let url = try result.get()
                    if url.startAccessingSecurityScopedResource() {
                        defer { url.stopAccessingSecurityScopedResource() }
                        let data = try Data(contentsOf: url)
                        manager.iceIcon = ControlItemImageSet(name: .custom, image: .data(data))
                    }
                } catch {
                    presentedError = LocalizedErrorWrapper(error)
                    isPresentingError = true
                }
            }

            if case .custom = manager.iceIcon.name {
                Toggle("Apply system theme to icon", isOn: manager.bindings.customIceIconIsTemplate)
                    .annotation("Display the icon as a monochrome image matching the system appearance")
            }
        }
    }

    @ViewBuilder
    private var iceBarOptions: some View {
        useIceBar
        if manager.useIceBar {
            iceBarLocationPicker
        }
    }

    @ViewBuilder
    private var useIceBar: some View {
        Toggle("Use Barp Bar", isOn: manager.bindings.useIceBar)
            .annotation("Show hidden menu bar items in a separate bar below the menu bar")
    }

    @ViewBuilder
    private var iceBarLocationPicker: some View {
        IcePicker("Location", selection: manager.bindings.iceBarLocation) {
            ForEach(IceBarLocation.allCases) { location in
                Text(location.localized).icePickerID(location)
            }
        }
        .annotation {
            switch manager.iceBarLocation {
            case .dynamic:
                Text("The Ice Bar's location changes based on context")
            case .mousePointer:
                Text("The Ice Bar is centered below the mouse pointer")
            case .iceIcon:
                Text("The Ice Bar is centered below the Ice icon")
            }
        }
    }

    @ViewBuilder
    private var showOnClick: some View {
        Toggle("Show on click", isOn: manager.bindings.showOnClick)
            .annotation("Click inside an empty area of the menu bar to show hidden menu bar items")
    }

    @ViewBuilder
    private var showOnHover: some View {
        Toggle("Show on hover", isOn: manager.bindings.showOnHover)
            .annotation("Hover over an empty area of the menu bar to show hidden menu bar items")
    }

    @ViewBuilder
    private var showOnScroll: some View {
        Toggle("Show on scroll", isOn: manager.bindings.showOnScroll)
            .annotation("Scroll or swipe in the menu bar to toggle hidden menu bar items")
    }

    @ViewBuilder
    private var rehideStrategyPicker: some View {
        IcePicker("Strategy", selection: manager.bindings.rehideStrategy) {
            ForEach(RehideStrategy.allCases) { strategy in
                Text(strategy.localized).icePickerID(strategy)
            }
        }
        .annotation {
            switch manager.rehideStrategy {
            case .smart:
                Text("Menu bar items are rehidden using a smart algorithm")
            case .timed:
                Text("Menu bar items are rehidden after a fixed amount of time")
            case .focusedApp:
                Text("Menu bar items are rehidden when the focused app changes")
            }
        }
    }

    /// Apply menu bar spacing offset.
    private func applyOffset() {
        isApplyingOffset = true
        manager.itemSpacingOffset = tempItemSpacingOffset
        Task {
            do {
                try await appState.spacingManager.applyOffset()
            } catch {
                let alert = NSAlert(error: error)
                alert.runModal()
            }
            isApplyingOffset = false
        }
    }

    /// Reset menu bar spacing offset to default.
    private func resetOffsetToDefault() {
        tempItemSpacingOffset = 0
        manager.itemSpacingOffset = tempItemSpacingOffset
        applyOffset()
    }
}

#Preview {
    GeneralSettingsPane()
        .fixedSize()
        .environmentObject(AppState())
}