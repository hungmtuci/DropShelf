import Foundation
import AppKit
import Carbon

@MainActor
final class HotKeyService: ObservableObject {
    static let shared = HotKeyService()

    @Published private(set) var isRecordingShortcut: Bool = false

    var onToggleShelf: (() -> Void)?

    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?
    private var recordingMonitor: Any?

    private init() {}

    func installHandlerAndRegister(binding: HotKeyBinding) {
        if eventHandlerRef == nil {
            var eventType = EventTypeSpec(
                eventClass: OSType(kEventClassKeyboard),
                eventKind: UInt32(kEventHotKeyPressed)
            )

            let callback: EventHandlerUPP = { _, event, _ -> OSStatus in
                var hotKeyID = EventHotKeyID()
                let status = GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hotKeyID
                )
                guard status == noErr else { return status }
                if hotKeyID.id == 1 {
                    Task { @MainActor in
                        HotKeyService.shared.onToggleShelf?()
                    }
                }
                return noErr
            }

            InstallEventHandler(
                GetApplicationEventTarget(),
                callback,
                1,
                &eventType,
                nil,
                &eventHandlerRef
            )
        }

        register(binding: binding)
    }

    func register(binding: HotKeyBinding) {
        if let existing = hotKeyRef {
            UnregisterEventHotKey(existing)
            hotKeyRef = nil
        }

        let hkID = EventHotKeyID(signature: OSType(0x44534846), id: 1) // 'DSHF'
        RegisterEventHotKey(
            binding.keyCode,
            binding.carbonModifiers,
            hkID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
    }

    func unregister() {
        stopRecordingShortcut()
        if let existing = hotKeyRef {
            UnregisterEventHotKey(existing)
            hotKeyRef = nil
        }
    }

    // MARK: - Live Custom Shortcut Recorder

    func startRecordingShortcut() {
        guard !isRecordingShortcut else { return }
        isRecordingShortcut = true

        if let existing = hotKeyRef {
            UnregisterEventHotKey(existing)
            hotKeyRef = nil
        }

        recordingMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            // Escape cancels recording
            if event.keyCode == UInt16(kVK_Escape) {
                self.stopRecordingShortcut()
                self.register(binding: AppSettings.shared.hotKeyBinding)
                return nil
            }

            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            var carbonMods: UInt32 = 0
            if flags.contains(.control) { carbonMods |= UInt32(controlKey) }
            if flags.contains(.option) { carbonMods |= UInt32(optionKey) }
            if flags.contains(.shift) { carbonMods |= UInt32(shiftKey) }
            if flags.contains(.command) { carbonMods |= UInt32(cmdKey) }

            let isFunctionKey = (Int(event.keyCode) >= kVK_F1 && Int(event.keyCode) <= kVK_F12)
                || Int(event.keyCode) == kVK_F5 || Int(event.keyCode) == kVK_F6
            guard carbonMods != 0 || isFunctionKey else {
                NSSound.beep()
                return nil
            }

            let newBinding = HotKeyBinding(keyCode: UInt32(event.keyCode), carbonModifiers: carbonMods)
            self.stopRecordingShortcut()
            AppSettings.shared.hotKeyBinding = newBinding
            AppSettings.shared.statusBannerMessage = "Đã cập nhật phím tắt mở Kệ sang \(newBinding.readableDisplay)!"
            return nil
        }
    }

    func stopRecordingShortcut() {
        isRecordingShortcut = false
        if let monitor = recordingMonitor {
            NSEvent.removeMonitor(monitor)
            recordingMonitor = nil
        }
    }
}
