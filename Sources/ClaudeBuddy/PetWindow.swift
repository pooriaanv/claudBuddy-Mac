import AppKit
import SwiftUI

let desktopLevel = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopIconWindow)) + 1)

/// Borderless, transparent, never steals focus.
final class PetPanel: NSPanel {
    init(frame: NSRect) {
        super.init(contentRect: frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        level = desktopLevel
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

/// Hosts the drawing and turns mouse input into click / drag callbacks.
final class PetHostView: NSHostingView<SceneView> {
    var onClick: (() -> Void)?
    var onDragBegan: (() -> Void)?
    /// Called with the cursor position (screen coordinates) and the grab offset inside the window.
    var onDragMoved: ((NSPoint, NSPoint) -> Void)?
    var onDragEnded: (() -> Void)?
    var canDrag: () -> Bool = { true }

    private var downAt: NSPoint?
    private var grab = NSPoint.zero
    private var dragging = false

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseDown(with event: NSEvent) {
        downAt = NSEvent.mouseLocation
        if let f = window?.frame { grab = NSPoint(x: NSEvent.mouseLocation.x - f.minX, y: NSEvent.mouseLocation.y - f.minY) }
        dragging = false
    }

    override func mouseDragged(with event: NSEvent) {
        guard canDrag(), let d = downAt else { return }
        let p = NSEvent.mouseLocation
        if !dragging && abs(p.x - d.x) + abs(p.y - d.y) > 4 {
            dragging = true
            onDragBegan?()
        }
        if dragging { onDragMoved?(p, grab) }
    }

    override func mouseUp(with event: NSEvent) {
        if dragging { onDragEnded?() } else { onClick?() }
        dragging = false
        downAt = nil
    }
}
