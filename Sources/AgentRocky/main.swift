import AppKit

let app = NSApplication.shared
let panelController = RockyPanelController()

print("AgentRocky starting")
fflush(stdout)
app.setActivationPolicy(.accessory)
installMainMenu()
DispatchQueue.main.async {
    panelController.show()
}
app.run()

@MainActor
private func installMainMenu() {
    let mainMenu = NSMenu()

    let appMenuItem = NSMenuItem()
    mainMenu.addItem(appMenuItem)

    let appMenu = NSMenu()
    appMenuItem.submenu = appMenu
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
