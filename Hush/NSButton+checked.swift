import Cocoa

extension NSButton {
  var checked: Bool {
    get {return state == NSOnState}
    set {state = newValue ? NSOnState : NSOffState}
  }
}
