import AppKit

let app = NSApplication.shared
let panelController = RockyPanelController()

print("AgentRocky starting")
fflush(stdout)
app.setActivationPolicy(.accessory)
DispatchQueue.main.async {
    panelController.show()
}
app.run()
