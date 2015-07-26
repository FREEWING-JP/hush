import Cocoa
import Carbon

func toOSType(string: String) -> OSType {
  var result: OSType = 0
  if let data = string.dataUsingEncoding(NSMacOSRomanStringEncoding) {
    let bytes = UnsafePointer<UInt8>(data.bytes)
    for i in 0..<data.length {
      result = result << 8 | OSType(bytes[i])
    }
  }
  return result
}

class HotKeys {
  static var handlers: [() -> ()] = []

  static func registerHotKey(keyCode: UInt32, modifiers: UInt32, block: () -> ()) {
    let hotKeyID = EventHotKeyID(signature: toOSType("hush"), id: 1)
    var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))

    let i = handlers.count
    handlers.append(block)

    InstallEventHandler(GetApplicationEventTarget(), {(_: EventHandlerCallRef, _: EventRef, index: UnsafeMutablePointer<Void>) -> OSStatus in
      HotKeys.handlers[unsafeBitCast(index, Word.self)]()
      return noErr
    }, 1, &eventType, UnsafeMutablePointer(bitPattern: Word(i)), nil)
    RegisterEventHotKey(keyCode, modifiers, hotKeyID, GetApplicationEventTarget(), OptionBits(0), nil)
  }
}
