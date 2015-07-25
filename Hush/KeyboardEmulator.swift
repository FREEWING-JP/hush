import Cocoa

class KeyboardEmulator {
  class func pressAndReleaseChar(char: UniChar, flags: CGEventFlags_ = [], eventSource es: CGEventSourceRef) {
    pressChar(char, flags: flags, eventSource: es)
    releaseChar(char, flags: flags, eventSource: es)
  }
  class func pressChar(var char: UniChar, keyDown: Bool = true, flags: CGEventFlags_ = [], eventSource es: CGEventSourceRef) {
    let event = CGEventCreateKeyboardEvent(es, 0, keyDown)
    if !flags.isEmpty {
      let flags = CGEventFlags(rawValue: UInt64(flags.rawValue))!
      CGEventSetFlags(event, flags)
    }
    CGEventKeyboardSetUnicodeString(event, 1, &char)
    CGEventPost(CGEventTapLocation.CGHIDEventTap, event)
  }
  class func releaseChar(char: UniChar, flags: CGEventFlags_ = [], eventSource es: CGEventSourceRef) {
    pressChar(char, keyDown: false, flags: flags, eventSource: es)
  }
}

extension KeyboardEmulator {
  class func pressAndReleaseKey(key: CGKeyCode, flags: CGEventFlags_ = [], eventSource es: CGEventSourceRef) {
    pressKey(key, flags: flags, eventSource: es)
    releaseKey(key, flags: flags, eventSource: es)
  }
  class func pressKey(key: CGKeyCode, keyDown: Bool = true, flags: CGEventFlags_ = [], eventSource es: CGEventSourceRef) {
    let event = CGEventCreateKeyboardEvent(es, key, keyDown)
    if !flags.isEmpty {
      let flags = CGEventFlags(rawValue: UInt64(flags.rawValue))!
      CGEventSetFlags(event, flags)
    }
    CGEventPost(CGEventTapLocation.CGHIDEventTap, event)
  }
  class func releaseKey(key: CGKeyCode, flags: CGEventFlags_ = [], eventSource es: CGEventSourceRef) {
    pressKey(key, keyDown: false, flags: flags, eventSource: es)
  }
}

extension KeyboardEmulator {
  class func replaceText(text: String, eventSource es: CGEventSourceRef) {
    selectAll(eventSource: es)
    NSOperationQueue.mainQueue().addOperationWithBlock {self.typeText(text, eventSource: es)}
  }
  class func typeText(text: String, eventSource es: CGEventSourceRef) {
    for char in text.utf16 {
      self.pressAndReleaseChar(char, eventSource: es)
    }
  }
  class func deleteAll(eventSource es: CGEventSourceRef) {
    selectAll(eventSource: es)
    NSOperationQueue.mainQueue().addOperationWithBlock {
      self.pressAndReleaseKey(CGKeyCode(kVK_Delete), eventSource: es)
    }
  }
  class func selectAll(eventSource es: CGEventSourceRef) {
    pressKey(CGKeyCode(kVK_Command), eventSource: es)
    pressAndReleaseKey(CGKeyCode(kVK_ANSI_A), flags: CGEventFlags_.Command, eventSource: es)
    releaseKey(CGKeyCode(kVK_Command), eventSource: es)
  }
}