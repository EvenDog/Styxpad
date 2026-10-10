// Draws the background of the DMG window (the "drag Styxpad into Applications" window):
// ink-blue, the STYXPAD wordmark, a glowing teal arrow between the two icon spots, and the river.
// Saves a normal and a Retina (2×) PNG. Used by make-release.sh:
//
//   swiftc -O Design/make-dmg-background.swift -o /tmp/make-dmg-background
//   /tmp/make-dmg-background /tmp/dmg-background.png /tmp/dmg-background@2x.png

import AppKit
import SwiftUI

/// The DMG window's content size in points. make-release.sh uses the same numbers.
let width: CGFloat = 640
let height: CGFloat = 400
/// Where Finder places the centers of the two icons (make-release.sh uses the same numbers).
let appIconCenter = CGPoint(x: 165, y: 205)
let applicationsIconCenter = CGPoint(x: 475, y: 205)
/// How far below an icon's center Finder draws its name (for 112-point icons, 13-point text).
let labelOffset: CGFloat = 75

let ink = Color(red: 0x0A / 255, green: 0x0F / 255, blue: 0x1A / 255)
let inkTop = Color(red: 0x14 / 255, green: 0x1E / 255, blue: 0x33 / 255)
let river = Color(red: 0x5E / 255, green: 0xEA / 255, blue: 0xD4 / 255)
let muted = Color(red: 0x8B / 255, green: 0x9A / 255, blue: 0xB3 / 255)

/// A gentle wave across its frame.
struct Wave: Shape {
    var waves = 2.0
    var amplitude: CGFloat = 6

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let steps = 160
        for i in 0...steps {
            let x = rect.minX + rect.width * CGFloat(i) / CGFloat(steps)
            let y = rect.midY + sin(Double(i) / Double(steps) * waves * 2 * .pi) * amplitude
            i == 0 ? path.move(to: CGPoint(x: x, y: y)) : path.addLine(to: CGPoint(x: x, y: y))
        }
        return path
    }
}

/// A wavy arrow from left to right, like a little river flowing into Applications.
struct FlowArrow: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Wave(waves: 1, amplitude: 7).path(in: CGRect(x: rect.minX, y: rect.minY, width: rect.width - 4, height: rect.height))
        let tip = CGPoint(x: rect.maxX, y: rect.midY)
        path.move(to: CGPoint(x: tip.x - 14, y: tip.y - 11))
        path.addLine(to: tip)
        path.addLine(to: CGPoint(x: tip.x - 14, y: tip.y + 11))
        return path
    }
}

struct Background: View {
    var body: some View {
        ZStack(alignment: .topLeading) {
            LinearGradient(colors: [inkTop, ink], startPoint: .top, endPoint: .bottom)

            VStack(spacing: 6) {
                Text("STYXPAD")
                    .font(.custom("Optima", size: 22).weight(.bold))
                    .tracking(5)
                    .foregroundStyle(.white)
                Text("Drag Styxpad into your Applications folder")
                    .font(.system(size: 13))
                    .foregroundStyle(muted)
            }
            .frame(width: width)
            .offset(y: 34)

            // Soft glowing pads where the two icons sit.
            ForEach([appIconCenter, applicationsIconCenter], id: \.x) { center in
                Circle()
                    .fill(RadialGradient(colors: [river.opacity(0.16), .clear], center: .center, startRadius: 0, endRadius: 95))
                    .frame(width: 190, height: 190)
                    .offset(x: center.x - 95, y: center.y - 95)
            }

            // Light "name tags" under the icons: Finder always draws the file names in black on a
            // custom background, so they need something light behind them to stay readable.
            ForEach([appIconCenter, applicationsIconCenter], id: \.x) { center in
                Capsule()
                    .fill(Color.white.opacity(0.82))
                    .frame(width: 124, height: 24)
                    .offset(x: center.x - 62, y: center.y + labelOffset - 12)
            }

            FlowArrow()
                .stroke(river, style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
                .shadow(color: river, radius: 8)
                .frame(width: 130, height: 30)
                .offset(x: (width - 130) / 2, y: appIconCenter.y - 15)

            // The river along the bottom.
            ForEach(0..<3, id: \.self) { i in
                Wave(waves: 2, amplitude: 6)
                    .stroke(river.opacity(0.18 + Double(i) * 0.14), lineWidth: 2)
                    .frame(width: width, height: 20)
                    .offset(y: height - 70 + CGFloat(i) * 14)
            }
        }
        .frame(width: width, height: height)
    }
}

@MainActor func save(scale: CGFloat, to path: String) {
    let renderer = ImageRenderer(content: Background())
    renderer.scale = scale
    guard let tiff = renderer.nsImage?.tiffRepresentation,
          let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:]) else {
        fatalError("Couldn't render the DMG background")
    }
    try! png.write(to: URL(fileURLWithPath: path))
}

MainActor.assumeIsolated {
    save(scale: 1, to: CommandLine.arguments[1])
    save(scale: 2, to: CommandLine.arguments[2])
}
print("Saved DMG background")
