import AppKit

let app = NSApplication.shared
let panelController = FloatingPanelController()
let appController = CompanionAppController(panelController: panelController)

print("AgentRocky starting")
fflush(stdout)
app.setActivationPolicy(.accessory)
app.delegate = appController
appController.installMenus()
app.run()

@MainActor
final class CompanionAppController: NSObject, NSApplicationDelegate {
    private let panelController: FloatingPanelController
    private let statusItem: NSStatusItem

    init(panelController: FloatingPanelController) {
        self.panelController = panelController
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()

        if let button = statusItem.button {
            button.title = "Rocky"
            button.target = self
            button.action = #selector(togglePanel)
        }
    }

    func installMenus() {
        installMainMenu()
        installStatusMenu()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        showPanelAfterLaunch()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showPanelAfterLaunch()
        return true
    }

    private func showPanelAfterLaunch() {
        DispatchQueue.main.async { [panelController] in
            panelController.show()
        }
    }

    private func installMainMenu() {
        let mainMenu = NSMenu()

        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)

        let appMenu = NSMenu()
        appMenuItem.submenu = appMenu
        let showItem = NSMenuItem(title: "Show Agent Rocky", action: #selector(showPanel), keyEquivalent: "r")
        showItem.target = self
        appMenu.addItem(showItem)

        let hideItem = NSMenuItem(title: "Hide Agent Rocky", action: #selector(hidePanel), keyEquivalent: "h")
        hideItem.target = self
        appMenu.addItem(hideItem)

        appMenu.addItem(.separator())
        appMenu.addItem(NSMenuItem(title: "Quit Agent Rocky", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

        let editMenuItem = NSMenuItem()
        mainMenu.addItem(editMenuItem)

        let editMenu = NSMenu(title: "Edit")
        editMenuItem.submenu = editMenu

        editMenu.addItem(NSMenuItem(title: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x"))
        editMenu.addItem(NSMenuItem(title: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c"))
        editMenu.addItem(NSMenuItem(title: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v"))
        editMenu.addItem(NSMenuItem(title: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a"))

        app.mainMenu = mainMenu
    }

    private func installStatusMenu() {
        let menu = NSMenu()
        let showItem = NSMenuItem(title: "Show Agent Rocky", action: #selector(showPanel), keyEquivalent: "")
        showItem.target = self
        menu.addItem(showItem)

        let hideItem = NSMenuItem(title: "Hide Agent Rocky", action: #selector(hidePanel), keyEquivalent: "")
        hideItem.target = self
        menu.addItem(hideItem)

        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit Agent Rocky", action: #selector(NSApplication.terminate(_:)), keyEquivalent: ""))

        statusItem.menu = menu
    }

    @objc private func showPanel() {
        panelController.show()
    }

    @objc private func hidePanel() {
        panelController.hide()
    }

    @objc private func togglePanel() {
        panelController.toggle()
    }
}
