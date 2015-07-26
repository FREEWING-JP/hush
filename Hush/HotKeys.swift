import Cocoa
import Carbon

class HotKeys {
  static func registerHotKey(keyCode: UInt32, modifiers: UInt32, block: () -> ()) {
    let hotKeyID = EventHotKeyID(signature: 1, id: 1)
    var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))

    let ptr = UnsafeMutablePointer<() -> ()>.alloc(1)
    ptr.initialize(block)

    InstallEventHandler(GetApplicationEventTarget(), {(_: EventHandlerCallRef, _: EventRef, ptr: UnsafeMutablePointer<Void>) -> OSStatus in
      UnsafeMutablePointer<() -> ()>(ptr).memory()
      return noErr
    }, 1, &eventType, ptr, nil)
    RegisterEventHotKey(keyCode, modifiers, hotKeyID, GetApplicationEventTarget(), OptionBits(0), nil)
  }
}
