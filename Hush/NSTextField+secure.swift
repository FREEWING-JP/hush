import Cocoa

extension NSTextField {
  var secure: Bool {
    get {return cell?.secure ?? false}
    set {
      guard newValue != secure else {return}
      let new = newValue ? NSSecureTextFieldCell() : NSTextFieldCell()
      if let attributed = placeholderAttributedString {
        new.placeholderAttributedString = attributed
      } else {
        new.placeholderString = placeholderString
      }
      if allowsEditingTextAttributes {
        new.attributedStringValue = attributedStringValue
      } else {
        new.stringValue = stringValue
      }
      new.selectable = selectable
      new.editable = editable
      new.bezeled = bezeled
      new.bezelStyle = bezelStyle
      new.font = font
      cell = new
      setNeedsDisplay()
    }
  }
}

extension NSCell {
  var secure: Bool {get {return false}}
}
extension NSSecureTextFieldCell {
  override var secure: Bool {get {return true}}
}
