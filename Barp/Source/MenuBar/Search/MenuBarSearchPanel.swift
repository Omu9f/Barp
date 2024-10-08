//
//  MenuBarSearchPanel.swift
//  Ice
//

import Combine
import Ifrit
import SwiftUI

final class MenuBarSearchPanel: NSPanel {
    static var defaultScreen: NSScreen? {
        NSScreen.screenWithMouse ?? NSScreen.main
    }

    private weak var appState: AppState?

    private var mouseDownMonitor: UniversalEventMonitor?

    private var keyDownMonitor: UniversalEventMonitor?

    private var cancellables = Set<AnyCancellable>()

    override var canBecomeKey: Bool { true }

    init(appState: AppState) {
        super.init(
            contentRect: .zero,
            styleMask: [.titled, .fullSizeContentView, .nonactivatingPanel, .hudWindow],
            backing: .buffered,
            defer: false
        )
        self.appState = appState
        self.titlebarAppearsTransparent = true
        self.isMovableByWindowBackground = false
        self.animationBehavior = .none
        self.level = .floating
        configureCancellables()
    }

    private func configureCancellables() {
        var c = Set<AnyCancellable>()

        NSApp.publisher(for: \.effectiveAppearance)
            .sink { [weak self] effectiveAppearance in
                self?.appearance = effectiveAppearance
            }
            .store(in: &c)

        // close the panel when the active space changes, or when the
        // screen parameters change
        Publishers.Merge(
            NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.activeSpaceDidChangeNotification),
            NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)
        )
        .sink { [weak self] _ in
            self?.close()
        }
        .store(in: &c)

        cancellables = c
    }

    func show(on screen: NSScreen) async {
        guard let appState else {
            return
        }

        // Set the desired frame size for the panel before positioning
        let panelSize = CGSize(width: 600, height: 400)
        setFrame(NSRect(origin: .zero, size: panelSize), display: false)

        // Important that we set the navigation before updating the cache
        appState.navigationState.isSearchPresented = true

        await appState.imageCache.updateCache()

        contentView = MenuBarSearchHostingView(appState: appState, closePanel: { [weak self] in
            self?.close()
        })

        mouseDownMonitor = UniversalEventMonitor(mask: [.leftMouseDown, .rightMouseDown, .otherMouseDown]) { [weak self, weak appState] event in
            guard
                let self,
                let appState,
                event.window !== self
            else {
                return event
            }
            if let lastItemMoveStartDate = appState.itemManager.lastItemMoveStartDate {
                guard Date.now.timeIntervalSince(lastItemMoveStartDate) > 1 else {
                    return event
                }
            }
            close()
            return event
        }
        keyDownMonitor = UniversalEventMonitor(mask: .keyDown) { [weak self] event in
            if KeyCode(rawValue: Int(event.keyCode)) == .escape {
                self?.close()
                return nil
            }
            return event
        }

        mouseDownMonitor?.start()
        keyDownMonitor?.start()

        // Calculate the top-left position
        let topLeft = CGPoint(
            x: screen.frame.midX - frame.width / 2,
            y: screen.frame.midY + (frame.height / 2) + (screen.frame.height / 8)
        )

        cascadeTopLeft(from: topLeft)
        makeKeyAndOrderFront(nil)
    }

    func toggle() async {
        if isVisible {
            close()
        } else if let screen = MenuBarSearchPanel.defaultScreen {
            await show(on: screen)
        }
    }

    override func close() {
        super.close()
        contentView = nil
        mouseDownMonitor?.stop()
        keyDownMonitor?.stop()
        mouseDownMonitor = nil
        keyDownMonitor = nil
        appState?.navigationState.isSearchPresented = false
    }
}

private final class MenuBarSearchHostingView: NSHostingView<AnyView> {
    override var safeAreaInsets: NSEdgeInsets {
        NSEdgeInsets()
    }

    init(
        appState: AppState,
        closePanel: @escaping () -> Void
    ) {
        super.init(
            rootView: MenuBarSearchContentView(closePanel: closePanel)
                .environmentObject(appState.itemManager)
                .environmentObject(appState.imageCache)
                .erasedToAnyView()
        )
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @available(*, unavailable)
    required init(rootView: AnyView) {
        fatalError("init(rootView:) has not been implemented")
    }
}

private struct MenuBarSearchContentView: View {
    private typealias ListItem = SectionedListItem<ItemID>

    private enum ItemID: Hashable {
        case header(MenuBarSection.Name)
        case item(MenuBarItemInfo)
    }

    @EnvironmentObject var itemManager: MenuBarItemManager
    @State private var searchText = ""
    @State private var displayedItems = [SectionedListItem<ItemID>]()
    @State private var selection: ItemID?
    @FocusState private var searchFieldIsFocused: Bool

    private let fuse = Fuse(threshold: 0.5)

    let closePanel: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            TextField(text: $searchText, prompt: Text("Search menu bar items…")) {
                Text("Search menu bar items…")
            }
            .labelsHidden()
            .textFieldStyle(.plain)
            .multilineTextAlignment(.leading)
            .font(.system(size: 18))
            .padding(15)
            .focused($searchFieldIsFocused)

            Divider()

            SectionedList(selection: $selection, items: $displayedItems)
                .contentPadding(8)
                .scrollContentBackground(.hidden)

            Divider()
                .offset(y: 1)
                .zIndex(1)

            HStack {
                SettingsButton {
                    closePanel()
                    itemManager.appState?.appDelegate?.openSettingsWindow()
                }

                Spacer()

                ShowItemButton {
                    guard
                        let selection,
                        let item = menuBarItem(for: selection)
                    else {
                        return
                    }
                    performAction(for: item)
                }
            }
            .padding(5)
            .background(.thinMaterial)
        }
        .background {
            VisualEffectView(material: .sheet, blendingMode: .behindWindow)
                .opacity(0.5)
        }
        .frame(width: 600, height: 400)
        .fixedSize()
        .task {
            searchFieldIsFocused = true
        }
        .onChange(of: searchText, initial: true) {
            updateDisplayedItems()
            selectFirstDisplayedItem()
        }
        .onChange(of: itemManager.itemCache, initial: true) {
            updateDisplayedItems()
        }
    }

    private func selectFirstDisplayedItem() {
        selection = displayedItems.first { $0.isSelectable }?.id
    }

    private func updateDisplayedItems() {
        let searchItems: [(listItem: ListItem, title: String)] = MenuBarSection.Name.allCases.reduce(into: []) { items, section in
            let headerItem = ListItem.header(id: .header(section)) {
                Text(section.displayString)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 10)
            }
            items.append((headerItem, section.displayString))

            for item in itemManager.itemCache.managedItems(for: section).reversed() {
                let listItem = ListItem.item(id: .item(item.info)) {
                    performAction(for: item)
                } content: {
                    MenuBarSearchItemView(item: item)
                }
                items.append((listItem, item.displayName))
            }
        }

        if searchText.isEmpty {
            displayedItems = searchItems.map { $0.listItem }
        } else {
            let selectableItems = searchItems.compactMap { searchItem in
                if searchItem.listItem.isSelectable {
                    return searchItem
                }
                return nil
            }
            let results = fuse.searchSync(searchText, in: selectableItems.map { $0.title })
            displayedItems = results.map { selectableItems[$0.index].listItem }
        }
    }

    private func menuBarItem(for selection: ItemID) -> MenuBarItem? {
        switch selection {
        case .item(let info):
            itemManager.itemCache.managedItems.first { $0.info == info }
        case .header:
            nil
        }
    }

    private func performAction(for item: MenuBarItem) {
        closePanel()
        itemManager.tempShowItem(item, clickWhenFinished: true, mouseButton: .left)
    }
}

private struct BottomBarButton<Content: View>: View {
    @State private var isHovering = false

    let content: Content
    let action: () -> Void

    init(action: @escaping () -> Void, @ViewBuilder content: () -> Content) {
        self.action = action
        self.content = content()
    }

    var body: some View {
        content
            .padding(3)
            .background {
                VisualEffectView(material: .selection, blendingMode: .withinWindow)
                    .clipShape(RoundedRectangle(cornerRadius: 5, style: .circular))
                    .opacity(isHovering ? 0.25 : 0)
            }
            .contentShape(Rectangle())
            .onHover { hovering in
                isHovering = hovering
            }
            .onTapGesture {
                action()
            }
    }
}

private struct SettingsButton: View {
    let action: () -> Void

    var body: some View {
        BottomBarButton(action: action) {
            Image(.iceCubeStroke)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 18, height: 18)
                .foregroundStyle(.secondary)
                .padding(2)
        }
    }
}

private struct ShowItemButton: View {
    @State private var isHovering = false

    let action: () -> Void

    var body: some View {
        BottomBarButton(action: action) {
            HStack {
                Text("Show item")
                    .padding(.horizontal, 5)

                Image(systemName: "return")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 11, height: 11)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 5)
                    .background {
                        VisualEffectView(material: .selection, blendingMode: .withinWindow)
                            .clipShape(RoundedRectangle(cornerRadius: 3, style: .circular))
                            .opacity(0.5)
                    }
            }
        }
    }
}

private let controlCenterIcon: NSImage? = {
    guard let app = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.controlcenter").first else {
        return nil
    }
    return app.icon
}()

private struct MenuBarSearchItemView: View {
    @EnvironmentObject var imageCache: MenuBarItemImageCache

    let item: MenuBarItem

    private var image: NSImage? {
        guard
            let image = imageCache.images[item.info],
            let screen = imageCache.screen
        else {
            return nil
        }
        let size = CGSize(
            width: CGFloat(image.width) / screen.backingScaleFactor,
            height: CGFloat(image.height) / screen.backingScaleFactor
        )
        return NSImage(cgImage: image, size: size)
    }

    private var appIcon: NSImage? {
        if item.info.namespace == .systemUIServer {
            controlCenterIcon
        } else {
            item.owningApplication?.icon
        }
    }

    var body: some View {
        HStack {
            if let appIcon {
                Image(nsImage: appIcon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 24, height: 24)
            }
            Text(item.displayName)
            Spacer()
            imageViewWithBackground
        }
        .padding(8)
    }

    @ViewBuilder
    private var imageViewWithBackground: some View {
        if let image {
            ZStack {
                VisualEffectView(material: .selection, blendingMode: .behindWindow)
                    .clipShape(
                        RoundedRectangle(cornerRadius: 5, style: .circular)
                    )
                    .opacity(0.75)
                    .frame(width: item.frame.width)
                    .overlay {
                        RoundedRectangle(cornerRadius: 5, style: .circular)
                            .inset(by: 0.5)
                            .stroke(lineWidth: 1)
                            .foregroundStyle(.white)
                            .opacity(0.15)
                    }

                Image(nsImage: image)
                    .frame(height: 24)
            }
        }
    }
}