import Cocoa
import SwiftUI

final class HUDWindowController {
    private var panel: NSPanel?
    private let stateHolder = HUDStateHolder()

    func show(state: HUDContentView.HUDState, anchorFrame: NSRect) {
        stateHolder.state = state

        if panel == nil {
            let size = HUDContentView.size
            let p = NSPanel(
                contentRect: NSRect(origin: .zero, size: size),
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered,
                defer: false
            )
            p.isOpaque = false
            p.backgroundColor = .clear
            p.hasShadow = true
            p.level = .statusBar
            p.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
            p.isReleasedWhenClosed = false

            let hosting = NSHostingView(rootView: HUDContentView(stateHolder: stateHolder))
            hosting.frame = NSRect(origin: .zero, size: size)
            p.contentView = hosting
            panel = p
        }

        guard let panel else { return }
        let size = panel.frame.size
        let x = anchorFrame.midX - size.width / 2
        let y = anchorFrame.minY - size.height - 6
        panel.setFrameOrigin(NSPoint(x: x, y: y))
        panel.alphaValue = 0
        panel.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.18
            panel.animator().alphaValue = 1
        }
    }

    func hide() {
        guard let panel else { return }
        NSAnimationContext.runAnimationGroup(
            { ctx in
                ctx.duration = 0.25
                panel.animator().alphaValue = 0
            },
            completionHandler: {
                panel.orderOut(nil)
            }
        )
    }
}
