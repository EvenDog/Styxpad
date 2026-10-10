// Finds the Tartarus over USB and takes exclusive control ("seizes") its keyboard part,
// so its original keystrokes no longer reach other apps. Every key press/release is
// reported through `onKey` instead. Uses IOKit HID, Apple's low-level framework for
// "Human Interface Devices" (keyboards, mice, gamepads).

import Foundation
import IOKit.hid

final class TartarusDevice {
    /// Called for every key press (true) or release (false), with the key's USB HID code.
    var onKey: ((UInt32, Bool) -> Void)?
    /// Called with a human-readable status message whenever the connection changes.
    var onStatusChange: ((String) -> Void)?
    /// Called when the last Tartarus interface disappears (e.g. unplugged).
    var onDisconnect: (() -> Void)?

    private let razerVendorID = 0x1532   // every Razer USB product uses this vendor number
    private let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
    private var seizedDevices: [IOHIDDevice] = []

    /// Starts watching for the Tartarus being plugged in (including if it's already plugged in).
    func start() {
        // Only look at Razer devices that act as a keyboard. This leaves the Tartarus's
        // mouse part (the scroll wheel) alone so it keeps working normally.
        let matching: [String: Any] = [
            kIOHIDVendorIDKey: razerVendorID,
            kIOHIDDeviceUsagePageKey: kHIDPage_GenericDesktop,
            kIOHIDDeviceUsageKey: kHIDUsage_GD_Keyboard,
        ]
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

        let result = IOHIDDeviceOpen(device, IOOptionBits(kIOHIDOptionsTypeSeizeDevice))
        guard result == kIOReturnSuccess else {
            let code = String(format: "0x%08X", UInt32(bitPattern: result))
            onStatusChange?("Found \(productName) but couldn't take control of it (error \(code)). "
                + "Check Input Monitoring permission, then quit and reopen the app.")
            return
        }

        let context = Unmanaged.passUnretained(self).toOpaque()
        IOHIDDeviceRegisterInputValueCallback(device, { context, _, _, value in
            Unmanaged<TartarusDevice>.fromOpaque(context!).takeUnretainedValue().inputReceived(value)
        }, context)
        IOHIDDeviceScheduleWithRunLoop(device, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)

        seizedDevices.append(device)
        onStatusChange?("Connected: \(productName)")
    }

    private func deviceDisappeared(_ device: IOHIDDevice) {
        guard seizedDevices.contains(where: { $0 === device }) else { return }
        seizedDevices.removeAll { $0 === device }
        if seizedDevices.isEmpty {
            onStatusChange?("Tartarus not connected")
            onDisconnect?()
        }
    }

    /// Called for every change in the device's state; we keep only keyboard key presses/releases.
    private func inputReceived(_ value: IOHIDValue) {
        let element = IOHIDValueGetElement(value)
        guard IOHIDElementGetUsagePage(element) == UInt32(kHIDPage_KeyboardOrKeypad) else { return }
        let usage = IOHIDElementGetUsage(element)
        // 0x04...0xE7 are real keys; values outside that are housekeeping (e.g. "too many keys").
        guard (0x04...0xE7).contains(usage) else { return }
        let isPressed = IOHIDValueGetIntegerValue(value) != 0
        onKey?(usage, isPressed)
    }
}
