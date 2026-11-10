import CoreGraphics
import Foundation
import IOKit
import IOKit.hid
import os

/// Watches which physical keyboard the latest key press came from, so key
/// translation can be limited to external keyboards. Needs the Input
/// Monitoring permission. Runs on its own thread so the answer is usually
/// ready before the matching event reaches the event tap.
final class KeyboardDeviceMonitor {
    static let shared = KeyboardDeviceMonitor()

    private struct State {
        var lastKeyWasExternal = false
        var externalNames: [String] = []
    }

    private let state = OSAllocatedUnfairLock(initialState: State())
    private var manager: IOHIDManager?
    private var thread: Thread?

    var lastKeyWasExternal: Bool { state.withLock { $0.lastKeyWasExternal } }
    var externalKeyboardNames: [String] { state.withLock { $0.externalNames } }
    var isRunning: Bool { thread != nil }

    var hasAccess: Bool {
        IOHIDCheckAccess(kIOHIDRequestTypeListenEvent) == kIOHIDAccessTypeGranted
    }

    /// Ask macOS for Input Monitoring. The app only shows up in the System
    /// Settings list once it has really tried to listen, so besides the two
    /// official request calls we also try to open the keyboards once.
    func requestAccess() {
        let hid = IOHIDRequestAccess(kIOHIDRequestTypeListenEvent)
        let cg = CGRequestListenEventAccess()

        let probe = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        let matching: [String: Int] = [
            kIOHIDDeviceUsagePageKey: kHIDPage_GenericDesktop,
            kIOHIDDeviceUsageKey: kHIDUsage_GD_Keyboard,
        ]
        IOHIDManagerSetDeviceMatching(probe, matching as CFDictionary)
        let opened = IOHIDManagerOpen(probe, IOOptionBits(kIOHIDOptionsTypeNone))
        IOHIDManagerClose(probe, IOOptionBits(kIOHIDOptionsTypeNone))

        NSLog("Kontrollglid: input monitoring request hid=%d cg=%d open=0x%08x check=%d",
              hid ? 1 : 0, cg ? 1 : 0, opened, IOHIDCheckAccess(kIOHIDRequestTypeListenEvent).rawValue)
    }

    func startIfNeeded() {
        guard thread == nil, hasAccess else { return }
        let thread = Thread { [weak self] in self?.run() }
        thread.name = "Kontrollglid.KeyboardDeviceMonitor"
        thread.qualityOfService = .userInteractive
        self.thread = thread
        thread.start()
    }

    private func run() {
        let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        self.manager = manager
        let matching: [[String: Int]] = [
            [kIOHIDDeviceUsagePageKey: kHIDPage_GenericDesktop, kIOHIDDeviceUsageKey: kHIDUsage_GD_Keyboard],
            [kIOHIDDeviceUsagePageKey: kHIDPage_GenericDesktop, kIOHIDDeviceUsageKey: kHIDUsage_GD_Keypad],
        ]
        IOHIDManagerSetDeviceMatchingMultiple(manager, matching as CFArray)

        let context = Unmanaged.passUnretained(self).toOpaque()
        IOHIDManagerRegisterInputValueCallback(manager, { context, _, _, value in
            guard let context else { return }
            Unmanaged<KeyboardDeviceMonitor>.fromOpaque(context).takeUnretainedValue().keyEvent(value)
        }, context)
        IOHIDManagerRegisterDeviceMatchingCallback(manager, { context, _, _, _ in
            guard let context else { return }
            Unmanaged<KeyboardDeviceMonitor>.fromOpaque(context).takeUnretainedValue().refreshDevices()
        }, context)
        IOHIDManagerRegisterDeviceRemovalCallback(manager, { context, _, _, _ in
            guard let context else { return }
            Unmanaged<KeyboardDeviceMonitor>.fromOpaque(context).takeUnretainedValue().refreshDevices()
        }, context)

        IOHIDManagerScheduleWithRunLoop(manager, CFRunLoopGetCurrent(), CFRunLoopMode.defaultMode.rawValue)
        IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        refreshDevices()
        CFRunLoopRun()
    }

    private func keyEvent(_ value: IOHIDValue) {
        let element = IOHIDValueGetElement(value)
        // Only real key presses: keyboard usage page, pressed, not a rollover code.
        guard IOHIDElementGetUsagePage(element) == UInt32(kHIDPage_KeyboardOrKeypad),
              IOHIDValueGetIntegerValue(value) != 0 else { return }
        let usage = IOHIDElementGetUsage(element)
        guard usage >= 4, usage <= 231 else { return }
        let external = !Self.isBuiltIn(IOHIDElementGetDevice(element))
        state.withLock { $0.lastKeyWasExternal = external }
    }

    private func refreshDevices() {
        guard let manager, let devices = IOHIDManagerCopyDevices(manager) as? Set<IOHIDDevice> else { return }
        var names: [String] = []
        for device in devices where !Self.isBuiltIn(device) {
            let name = IOHIDDeviceGetProperty(device, kIOHIDProductKey as CFString) as? String ?? "Unknown keyboard"
            if !names.contains(name) { names.append(name) }
        }
        let sorted = names.sorted()
        state.withLock { $0.externalNames = sorted }
    }

    private static func isBuiltIn(_ device: IOHIDDevice) -> Bool {
        (IOHIDDeviceGetProperty(device, kIOHIDBuiltInKey as CFString) as? Bool) ?? false
    }
}
