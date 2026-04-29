import AppKit
import SwiftUI

final class RockyFloatingPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

@MainActor
final class RockyPanelController {
    private let panel: NSPanel
    private let viewModel: RockyViewModel

    init() {
        viewModel = RockyViewModel()

        let rootView = RockyRootView(viewModel: viewModel)
        let hostingController = NSHostingController(rootView: rootView)
        let initialSize = NSSize(width: 360, height: 390)
        hostingController.view.frame = NSRect(origin: .zero, size: initialSize)

        panel = RockyFloatingPanel(
            contentRect: NSRect(origin: .zero, size: initialSize),
            styleMask: [.borderless, .fullSizeContentView, .resizable, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        panel.contentViewController = hostingController
        panel.setContentSize(initialSize)
        panel.title = "Agent Rocky"
        panel.isMovableByWindowBackground = true
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.level = .statusBar
        panel.minSize = NSSize(width: 240, height: 250)
        panel.maxSize = NSSize(width: 620, height: 720)
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
    }

    func show() {
        positionNearDock()
        panel.orderFrontRegardless()
        logLaunchState()
    }

    private func positionNearDock() {
        guard let screenFrame = panel.screen?.visibleFrame ?? NSScreen.main?.visibleFrame else {
            panel.setFrameOrigin(NSPoint(x: 120, y: 120))
            return
        }

        if screenFrame.width <= 1 || screenFrame.height <= 1 {
            panel.setFrameOrigin(NSPoint(x: 120, y: 120))
            return
        }

        let x = screenFrame.midX - panel.frame.width / 2
        let y = screenFrame.minY + 18
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }

    private func logLaunchState() {
        let screen = NSScreen.main?.visibleFrame ?? .zero
        let frame = panel.frame
        print(
            "AgentRocky launched panelFrame=\(Int(frame.origin.x)),\(Int(frame.origin.y)),\(Int(frame.width))x\(Int(frame.height)) screen=\(Int(screen.origin.x)),\(Int(screen.origin.y)),\(Int(screen.width))x\(Int(screen.height))"
        )
        fflush(stdout)
    }
}
