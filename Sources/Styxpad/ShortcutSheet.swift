import AppKit

/// A snapshot of one profile, printed without changing its saved mappings.
enum ShortcutSheet {
    static func printProfile(_ profile: Profile, layer: Layer, macros: [Macro], blank: Bool = false) {
        let view = ShortcutSheetView(profile: profile, layer: layer, macros: macros, blank: blank)
        let info = NSPrintInfo.shared.copy() as! NSPrintInfo
        info.orientation = .portrait
        info.topMargin = 36
        info.bottomMargin = 36
        info.leftMargin = 36
        info.rightMargin = 36
        info.horizontalPagination = .fit
        info.verticalPagination = .fit
        info.isHorizontallyCentered = true
        info.isVerticallyCentered = true
        let operation = NSPrintOperation(view: view, printInfo: info)
        operation.jobTitle = "Styxpad — \(profile.name) shortcuts"
        operation.run()
    }
}

/// Black text on white paper, with generous blank cells for handwritten descriptions.
/// The fixed canvas fits Letter and scales to other paper sizes in the print dialog.
final class ShortcutSheetView: NSView {
    private let profile: Profile
    private let shortcutLayer: Layer
    private let macros: [Macro]
    private let blank: Bool

    init(profile: Profile, layer: Layer, macros: [Macro], blank: Bool = false) {
        self.profile = profile
        self.shortcutLayer = layer
        self.macros = macros
        self.blank = blank
        super.init(frame: NSRect(x: 0, y: 0, width: 540, height: 720))
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override var isFlipped: Bool { true }

    func mapping(for key: PhysicalKey) -> String {
        if blank { return "" }
        if key.id == profile.hypershiftKeyID { return "Hold for Hypershift" }
        let action = profile.action(for: key.id, in: shortcutLayer)
            ?? profile.action(for: key.id, in: .normal)
        return action?.displayName(macros: macros) ?? key.defaultName
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.white.setFill()
        bounds.fill()
        text("STYXPAD · SHORTCUT SHEET", x: 0, y: 0, width: 540, size: 18, bold: true)
        text(profile.name.isEmpty ? "Untitled" : profile.name,
             x: 0, y: 29, width: 540, size: 14, bold: true)
        text(blank ? "Blank worksheet · Fill in your shortcuts and what they do."
             : "\(shortcutLayer.rawValue) layer · Write what each shortcut does in the last column.",
             x: 0, y: 52, width: 540, size: 10)

        let keys = TartarusLayout.mainRows.flatMap { $0 }
            + [TartarusLayout.thumbKey, TartarusLayout.sideButton,
               TartarusLayout.dpadUp, TartarusLayout.dpadDown,
               TartarusLayout.dpadLeft, TartarusLayout.dpadRight,
               TartarusLayout.wheelUp, TartarusLayout.wheelClick, TartarusLayout.wheelDown]
        let top: CGFloat = 80
        let rowHeight: CGFloat = 21
        let bottom = top + rowHeight * CGFloat(keys.count + 1)
        NSColor(white: 0.93, alpha: 1).setFill()
        NSRect(x: 0, y: top, width: 540, height: rowHeight).fill()
        text("Button", x: 7, y: top + 4, width: 83, size: 10, bold: true)
        text("Shortcut", x: 99, y: top + 4, width: 172, size: 10, bold: true)
        text("What it does", x: 287, y: top + 4, width: 246, size: 10, bold: true)
        for (index, key) in keys.enumerated() {
            let y = top + rowHeight * CGFloat(index + 1) + 4
            let label: String
            switch key.id {
            case "dpadUp": label = "D-pad Up"
            case "dpadDown": label = "D-pad Down"
            case "dpadLeft": label = "D-pad Left"
            case "dpadRight": label = "D-pad Right"
            case "20": label = "20 (thumb)"
            default: label = key.label
            }
            text(label, x: 7, y: y, width: 83, size: 10, bold: true)
            text(mapping(for: key), x: 99, y: y, width: 172, size: 10)
        }
        NSColor(white: 0.65, alpha: 1).setStroke()
        let grid = NSBezierPath()
        grid.lineWidth = 0.5
        for row in 0...(keys.count + 1) {
            let y = top + CGFloat(row) * rowHeight
            grid.move(to: NSPoint(x: 0, y: y))
            grid.line(to: NSPoint(x: 540, y: y))
        }
        for x: CGFloat in [0, 92, 280, 540] {
            grid.move(to: NSPoint(x: x, y: top))
            grid.line(to: NSPoint(x: x, y: bottom))
        }
        grid.stroke()
        text("⌃ Control   ⌥ Option / Alt   ⇧ Shift   ⌘ Command", x: 0, y: 697, width: 540, size: 9)
        if shortcutLayer == .hypershift && !blank {
            text("Unassigned Hypershift buttons use their Normal shortcuts.", x: 0, y: 709, width: 540, size: 8)
        }
    }

    private func text(_ value: String, x: CGFloat, y: CGFloat, width: CGFloat,
                      size: CGFloat, bold: Bool = false) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineBreakMode = .byTruncatingTail
        let singleLine = value.components(separatedBy: .newlines).joined(separator: " ")
        (singleLine as NSString).draw(in: NSRect(x: x, y: y, width: width, height: size + 4),
                                    withAttributes: [
                                        .font: bold ? NSFont.boldSystemFont(ofSize: size) : NSFont.systemFont(ofSize: size),
                                        .foregroundColor: NSColor.black,
                                        .paragraphStyle: paragraph,
                                    ])
    }
}
