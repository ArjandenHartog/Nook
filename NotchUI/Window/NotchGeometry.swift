import AppKit

/// De maten van de notch op één scherm. Macs zonder notch krijgen een gesimuleerde notch
/// onder de menubalk, zodat Nook overal hetzelfde werkt.
struct NotchGeometry: Equatable {
    var screenFrame: CGRect
    var hasNotch: Bool
    var notchWidth: CGFloat
    var notchHeight: CGFloat

    static let placeholder = NotchGeometry(
        screenFrame: .zero, hasNotch: false, notchWidth: 180, notchHeight: 34
    )

    static func make(for screen: NSScreen) -> NotchGeometry {
        let frame = screen.frame
        let inset = screen.safeAreaInsets.top
        if inset > 0, let left = screen.auxiliaryTopLeftArea, let right = screen.auxiliaryTopRightArea {
            return NotchGeometry(
                screenFrame: frame,
                hasNotch: true,
                notchWidth: frame.width - left.width - right.width,
                notchHeight: inset
            )
        }
        let menuBar = max(frame.maxY - screen.visibleFrame.maxY, 24)
        return NotchGeometry(screenFrame: frame, hasNotch: false, notchWidth: 180, notchHeight: menuBar)
    }

    /// Kiest het scherm met een notch, anders het hoofdscherm.
    static func preferredScreen() -> NSScreen {
        NSScreen.screens.first { $0.safeAreaInsets.top > 0 }
            ?? NSScreen.main
            ?? NSScreen.screens[0]
    }
}
