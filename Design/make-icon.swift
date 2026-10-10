// Draws Styxpad's app icon (a glowing keycap with a carved "S" above the river Styx) and saves
// every size macOS needs into an .iconset folder. Not part of the app — a tool you run by hand:
//
//   swiftc -O Design/make-icon.swift -o /tmp/make-icon
//   /tmp/make-icon /tmp/AppIcon.iconset
//   iconutil -c icns /tmp/AppIcon.iconset -o Resources/AppIcon.icns

import AppKit
import SwiftUI

let ink = Color(red: 0x0A / 255, green: 0x0F / 255, blue: 0x1A / 255)
let inkTop = Color(red: 0x16 / 255, green: 0x21 / 255, blue: 0x38 / 255)
let river = Color(red: 0x5E / 255, green: 0xEA / 255, blue: 0xD4 / 255)

/// A gentle wave across the width of its frame.
struct Wave: Shape {
    var waves = 1.5
    var amplitude: CGFloat = 30

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let steps = 200
        for i in 0...steps {
            let x = rect.minX + rect.width * CGFloat(i) / CGFloat(steps)
            let y = rect.midY + sin(Double(i) / Double(steps) * waves * 2 * .pi) * amplitude
            i == 0 ? path.move(to: CGPoint(x: x, y: y)) : path.addLine(to: CGPoint(x: x, y: y))
        }
        return path
    }
}

/// The icon, drawn on Apple's 1024 × 1024 template: an 824-point rounded square with a shadow.
struct AppIcon: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 185, style: .continuous)
                .fill(LinearGradient(colors: [inkTop, ink], startPoint: .top, endPoint: .bottom))
                .overlay(RoundedRectangle(cornerRadius: 185, style: .continuous)
                    .strokeBorder(LinearGradient(colors: [.white.opacity(0.18), .white.opacity(0.02)],
                                                 startPoint: .top, endPoint: .bottom), lineWidth: 3))
            // The river: a faint wave behind a bright, glowing one.
            Wave().stroke(river.opacity(0.35), lineWidth: 10).frame(width: 824, height: 120).offset(y: 250)
            Wave().stroke(river, lineWidth: 16).frame(width: 824, height: 120).offset(y: 215)
                .shadow(color: river, radius: 22)
            // The keycap, glowing teal underneath like the Tartarus backlight.
            RoundedRectangle(cornerRadius: 78, style: .continuous)
                .fill(LinearGradient(colors: [Color(white: 0.24), Color(white: 0.11)], startPoint: .top, endPoint: .bottom))
                .overlay(RoundedRectangle(cornerRadius: 78, style: .continuous).strokeBorder(river.opacity(0.75), lineWidth: 5))
                .frame(width: 430, height: 390)
                .shadow(color: river.opacity(0.8), radius: 50, y: 20)
                .offset(y: -60)
            Text("S")
                .font(.custom("Optima", size: 300).weight(.bold))
                .foregroundStyle(LinearGradient(colors: [.white, Color(white: 0.8)], startPoint: .top, endPoint: .bottom))
                .offset(y: -66)
        }
        .frame(width: 824, height: 824)
        .clipShape(RoundedRectangle(cornerRadius: 185, style: .continuous))
        .shadow(color: .black.opacity(0.35), radius: 18, y: 12)
        .frame(width: 1024, height: 1024)
    }
}

/// Renders the icon at `pixels` × `pixels` and saves it as a PNG.
@MainActor func save(pixels: Int, to url: URL) {
    let size = CGFloat(pixels)
    let renderer = ImageRenderer(content: AppIcon().scaleEffect(size / 1024).frame(width: size, height: size))
    renderer.scale = 1
    guard let tiff = renderer.nsImage?.tiffRepresentation,
          let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:]) else {
        fatalError("Couldn't render \(pixels)px")
    }
    try! png.write(to: url)
}

let folder = URL(fileURLWithPath: CommandLine.arguments[1])
try! FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
MainActor.assumeIsolated {
    // The file names iconutil expects: each point size at 1x and 2x (Retina).
    for points in [16, 32, 128, 256, 512] {
        save(pixels: points, to: folder.appendingPathComponent("icon_\(points)x\(points).png"))
        save(pixels: points * 2, to: folder.appendingPathComponent("icon_\(points)x\(points)@2x.png"))
    }
}
print("Saved icon sizes to \(folder.path)")
