import Cocoa

// Apple messed this up, so use our own

struct CGEventFlags_ : OptionSetType {
  let rawValue: Int

  init() {rawValue = 0}
  init(rawValue: Int) {self.rawValue = rawValue}

  static var MaskAlphaShift: CGEventFlags_ {return CGEventFlags_()}
  static var AlphaShift: CGEventFlags_ {return CGEventFlags_(rawValue: Int(NX_ALPHASHIFTMASK))}
  static var Shift: CGEventFlags_ {return CGEventFlags_(rawValue: Int(NX_SHIFTMASK))}
  static var Control: CGEventFlags_ {return CGEventFlags_(rawValue: Int(NX_CONTROLMASK))}
  static var Alternate: CGEventFlags_ {return CGEventFlags_(rawValue: Int(NX_ALTERNATEMASK))}
  static var Command: CGEventFlags_ {return CGEventFlags_(rawValue: Int(NX_COMMANDMASK))}
  static var Help: CGEventFlags_ {return CGEventFlags_(rawValue: Int(NX_HELPMASK))}
  static var SecondaryFn: CGEventFlags_ {return CGEventFlags_(rawValue: Int(NX_SECONDARYFNMASK))}
  static var NumericPad: CGEventFlags_ {return CGEventFlags_(rawValue: Int(NX_NUMERICPADMASK))}
  static var NonCoalesced: CGEventFlags_ {return CGEventFlags_(rawValue: Int(NX_NONCOALSESCEDMASK))}
}
