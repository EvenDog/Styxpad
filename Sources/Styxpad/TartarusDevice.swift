// Finds the Tartarus over USB, listens to its key presses, and reports each press/release
// through `onKey`. Uses IOKit HID, Apple's low-level framework for "Human Interface Devices"
// (keyboards, mice, gamepads).
//
// To stop the Tartarus's original keys reaching other apps, it asks macOS (via Apple's
// `hidutil` tool) to remap every Tartarus key to "no key" — for this one device only.
// We still receive the raw presses, because we read them straight from the USB device.
// (Taking exclusive control of a keyboard instead would require running as root.)

import Foundation
import IOKit.hid
import os

private let log = Logger(subsystem: "com.danielschultz.Styxpad", category: "device")

final class TartarusDevice {
    /// Called for every key press (true) or release (false), with the key's USB HID code.
    var onKey: ((UInt32, Bool) -> Void)?
    /// Called with a human-readable status message whenever the connection changes.
    var onStatusChange: ((String) -> Void)?
    /// Called when the last Tartarus interface disappears (e.g. unplugged).
    var onDisconnect: (() -> Void)?

    private let razerVendorID = 0x1532   // every Razer USB product uses this vendor number
    private let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
    private var openDevices: [IOHIDDevice] = []

    /// Starts watching for the Tartarus being plugged in (including if it's already plugged in).
    func start() {
        // Look at every part of any Razer device (the Tartarus appears as several: keyboard,
        // mouse, ...). We only listen, so the scroll wheel keeps working normally.
        let matching: [String: Any] = [kIOHIDVendorIDKey: razerVendorID]
        IOHIDManagerSetDeviceMatching(manager, matching as CFDictionary)

        // IOKit is a C API, so its callbacks can't capture Swift variables. Instead we pass
        // a raw pointer to `self` as "context" and turn it back into our object inside.
        let context = Unmanaged.passUnretained(self).toOpaque()
        IOHIDManagerRegisterDeviceMatchingCallback(manager, { context, _, _, device in
            Unmanaged<TartarusDevice>.fromOpaque(context!).takeUnretainedValue().deviceAppeared(device)
        }, context)
        IOHIDManagerRegisterDeviceRemovalCallback(manager, { context, _, _, device in
            Unmanaged<TartarusDevice>.fromOpaque(context!).takeUnretainedValue().deviceDisappeared(device)
        }, context)

        // Deliver callbacks on the main thread's run loop (the app's main event loop).
        IOHIDManagerScheduleWithRunLoop(manager, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
        onStatusChange?("Tartarus not connected")
    }

    private func deviceAppeared(_ device: IOHIDDevice) {
        let productName = IOHIDDeviceGetProperty(device, kIOHIDProductKey as CFString) as? String ?? ""
        // Skip other Razer keyboards (e.g. a BlackWidow) — we only want the Tartarus.
        guard productName.localizedCaseInsensitiveContains("Tartarus") else { return }

        let result = IOHIDDeviceOpen(device, IOOptionBits(kIOHIDOptionsTypeNone))
        let primaryUsagePage = IOHIDDeviceGetProperty(device, kIOHIDPrimaryUsagePageKey as CFString) as? Int ?? -1
        let primaryUsage = IOHIDDeviceGetProperty(device, kIOHIDPrimaryUsageKey as CFString) as? Int ?? -1
        log.debug("""
            found \(productName, privacy: .public) part: page 0x\(String(primaryUsagePage, radix: 16), privacy: .public) \
            usage 0x\(String(primaryUsage, radix: 16), privacy: .public), open result 0x\(String(UInt32(bitPattern: result), radix: 16), privacy: .public)
            """)
        guard result == kIOReturnSuccess else {
            // Some parts of the device may refuse to open; that's fine as long as one part works.
            guard openDevices.isEmpty else { return }
            let code = String(format: "0x%08X", UInt32(bitPattern: result))
            onStatusChange?("Found \(productName) but couldn't read it (error \(code)). "
                + "Check Input Monitoring permission, then quit and reopen the app.")
            return
        }
        setKeysMuted(true, on: device)

        let context = Unmanaged.passUnretained(self).toOpaque()
        IOHIDDeviceRegisterInputValueCallback(device, { context, _, _, value in
            Unmanaged<TartarusDevice>.fromOpaque(context!).takeUnretainedValue().inputReceived(value)
        }, context)
        IOHIDDeviceScheduleWithRunLoop(device, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)

        openDevices.append(device)
        onStatusChange?("Connected: \(productName)")
    }

    private func deviceDisappeared(_ device: IOHIDDevice) {
        guard openDevices.contains(where: { $0 === device }) else { return }
        openDevices.removeAll { $0 === device }
        if openDevices.isEmpty {
            onStatusChange?("Tartarus not connected")
            onDisconnect?()
        }
    }

    /// Gives the Tartarus its normal keys back. Call this when the app quits.
    /// (If the app crashes instead, unplugging and replugging the Tartarus also resets it.)
    func stop() {
        for device in openDevices { setKeysMuted(false, on: device) }
    }

    /// Mutes (or un-mutes) every known Tartarus key at the macOS level, for this device only.
    /// Runs the same command you could type in Terminal:
    ///   hidutil property --matching '{"VendorID":…,"ProductID":…}' --set '{"UserKeyMapping":[…]}'
    private func setKeysMuted(_ muted: Bool, on device: IOHIDDevice) {
        guard let vendorID = IOHIDDeviceGetProperty(device, kIOHIDVendorIDKey as CFString) as? Int,
              let productID = IOHIDDeviceGetProperty(device, kIOHIDProductIDKey as CFString) as? Int
        else { return }

        // hidutil identifies a key as (usage page << 32) | usage. Keyboard keys are on page 7,
        // and usage 0 on that page means "no key" — so mapping a key there silences it.
        let keyboardPage: UInt64 = 0x7_0000_0000
        let mappings = muted ? TartarusLayout.allKeys.map { key in
            "{\"HIDKeyboardModifierMappingSrc\":\(keyboardPage | UInt64(key.defaultHIDUsage)),"
                + "\"HIDKeyboardModifierMappingDst\":\(keyboardPage)}"
        } : []

        let hidutil = Process()
        hidutil.executableURL = URL(fileURLWithPath: "/usr/bin/hidutil")
        hidutil.arguments = [
            "property",
            "--matching", "{\"VendorID\":\(vendorID),\"ProductID\":\(productID)}",
            "--set", "{\"UserKeyMapping\":[\(mappings.joined(separator: ","))]}",
        ]
        hidutil.standardOutput = FileHandle.nullDevice   // hidutil prints the mapping; we don't need it
        do {
            try hidutil.run()
            hidutil.waitUntilExit()
        } catch {
            onStatusChange?("Couldn't run hidutil to mute the Tartarus's original keys: \(error)")
        }
    }

    /// Called for every change in the device's state; we keep only keyboard key presses/releases.
    private func inputReceived(_ value: IOHIDValue) {
        let element = IOHIDValueGetElement(value)
        let usagePage = IOHIDElementGetUsagePage(element)
        let usage = IOHIDElementGetUsage(element)
        guard usagePage == UInt32(kHIDPage_KeyboardOrKeypad) else {
            // Not a normal key (e.g. scroll wheel, or a special button). Logged so we can
            // discover what buttons like the profile switch send.
            log.debug("""
                other input: page 0x\(String(usagePage, radix: 16), privacy: .public) \
                usage 0x\(String(usage, radix: 16), privacy: .public) \
                value \(IOHIDValueGetIntegerValue(value), privacy: .public)
                """)
            return
        }
        // 0x04...0xE7 are real keys; values outside that are housekeeping (e.g. "too many keys").
        guard (0x04...0xE7).contains(usage) else { return }
        let isPressed = IOHIDValueGetIntegerValue(value) != 0
        onKey?(usage, isPressed)
    }
}
