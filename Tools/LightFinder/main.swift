// A one-time helper for per-key lighting: lights the Tartarus's backlight lights one at a
// time and asks which key each one is under. The answers tell us the right order for
// TartarusLayout.lightOrder. It sends only the per-key ("custom frame") lighting commands
// from RazerProtocol.swift — the same ones Styxpad uses.
//
// Run it with Tools/find-lights.sh (that script builds it together with the app's files).

import Foundation
import IOKit.hid

/// Finds the part of the Tartarus Pro that accepts lighting commands (the "mouse" part,
/// usage page 1, usage 2 — the same one Styxpad uses) and opens it.
func openLightingPart() -> IOHIDDevice? {
    let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
    IOHIDManagerSetDeviceMatching(manager, [kIOHIDVendorIDKey: 0x1532, kIOHIDProductIDKey: 0x0244] as CFDictionary)
    let parts = (IOHIDManagerCopyDevices(manager) as? Set<IOHIDDevice>) ?? []
    for part in parts {
        let page = IOHIDDeviceGetProperty(part, kIOHIDPrimaryUsagePageKey as CFString) as? Int
        let usage = IOHIDDeviceGetProperty(part, kIOHIDPrimaryUsageKey as CFString) as? Int
        if page == 1 && usage == 2 && IOHIDDeviceOpen(part, IOOptionBits(kIOHIDOptionsTypeNone)) == kIOReturnSuccess {
            return part
        }
    }
    return nil
}

/// Sends one 90-byte command and reads the reply. Returns true if the Tartarus accepted it
/// (reply status byte 0x02 = success).
func send(_ report: [UInt8], to part: IOHIDDevice) -> Bool {
    guard IOHIDDeviceSetReport(part, kIOHIDReportTypeFeature, 0, report, report.count) == kIOReturnSuccess else { return false }
    usleep(1000)
    var reply = [UInt8](repeating: 0, count: 90)
    var replyLength = reply.count
    guard IOHIDDeviceGetReport(part, kIOHIDReportTypeFeature, 0, &reply, &replyLength) == kIOReturnSuccess else { return false }
    return reply[0] == 0x02
}

/// Shows exactly one light (white), all others off.
func showOnly(light index: Int, of count: Int, on part: IOHIDDevice) -> Bool {
    let off = RGBColor(red: 0, green: 0, blue: 0)
    var colors = [RGBColor](repeating: off, count: count)
    colors[index] = RGBColor(red: 255, green: 255, blue: 255)
    return send(RazerProtocol.customFrameReport(colors: colors), to: part)
        && send(RazerProtocol.customEffectReport(), to: part)
}

let lightCount = TartarusLayout.lightOrder.count   // 21 for the Tartarus Pro
guard let part = openLightingPart() else {
    print("Couldn't find or open the Tartarus Pro. Is it plugged in? (Quit Styxpad first.)")
    exit(1)
}

print("""
Light finder: \(lightCount) lights, one at a time, in white.
For each one, type the number of the key that's lit (01–20), or "wheel", or "none"
if you can't see anything, then press Return.

""")

var answers: [String] = []
for index in 0..<lightCount {
    guard showOnly(light: index, of: lightCount, on: part) else {
        print("The Tartarus didn't accept the command for light \(index). Stopping.")
        exit(1)
    }
    if index == 0 {
        print("(Also: are the 3 small side lights still showing the profile, or did they change? Note it for later.)")
    }
    print("Light \(index) of \(lightCount - 1) is on. Which key? ", terminator: "")
    answers.append(readLine()?.trimmingCharacters(in: .whitespaces) ?? "")
}

print("\nDone. Paste this back to Claude:\n")
print("LIGHT ORDER: " + answers.enumerated().map { "\($0.offset)=\($0.element)" }.joined(separator: " "))
print("\nOpen Styxpad again to get your normal lighting back.")
