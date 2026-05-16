import AppKit
import SwiftUI

final class CompanionFloatingPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

@MainActor
final class FloatingPanelController {
    private let panel: NSPanel
    private let viewModel: CompanionAppViewModel

    init() {
        viewModel = CompanionAppViewModel()

        let rootView = RootView(viewModel: viewModel)
        let hostingController = NSHostingController(rootView: rootView)
        let initialSize = NSSize(width: 330, height: 320)
        hostingController.view.frame = NSRect(origin: .zero, size: initialSize)

        panel = CompanionFloatingPanel(
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
        panel.minSize = NSSize(width: 220, height: 220)
        panel.maxSize = NSSize(width: 1100, height: 900)
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
    }

    func show() {
        positionNearDock()
        panel.orderFrontRegardless()
        logLaunchState()
    }

    func hide() {
        panel.orderOut(nil)
    }

    func toggle() {
        if panel.isVisible {
            hide()
        } else {
            show()
        }
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
