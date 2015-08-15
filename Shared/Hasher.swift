#if os(iOS)
  import UIKit
#else
  import Cocoa
#endif

@objc class HashOptions : NSObject, NSCoding {
  dynamic var length = 16
  dynamic var requireDigit = true
  dynamic var requireSpecial = true
  dynamic var requireMixed = true
  dynamic var forbidSpecial = false
  dynamic var onlyDigits = false

  required override init() {}
  required init?(coder aDecoder: NSCoder) {
    length = aDecoder.decodeIntegerForKey("length")
    requireDigit = aDecoder.decodeBoolForKey("requireDigit")
    requireSpecial = aDecoder.decodeBoolForKey("requireSpecial")
    requireMixed = aDecoder.decodeBoolForKey("requireMixed")
    forbidSpecial = aDecoder.decodeBoolForKey("forbidSpecial")
    onlyDigits = aDecoder.decodeBoolForKey("onlyDigits")
  }
  func encodeWithCoder(aCoder: NSCoder) {
    aCoder.encodeInteger(length, forKey: "length")
    aCoder.encodeBool(requireDigit, forKey: "requireDigit")
    aCoder.encodeBool(requireSpecial, forKey: "requireSpecial")
    aCoder.encodeBool(requireMixed, forKey: "requireMixed")
    aCoder.encodeBool(forbidSpecial, forKey: "forbidSpecial")
    aCoder.encodeBool(onlyDigits, forKey: "onlyDigits")
  }

  func setTo(o: HashOptions) {
    length = o.length
    requireDigit = o.requireDigit
    requireSpecial = o.requireSpecial
    requireMixed = o.requireMixed
    forbidSpecial = o.forbidSpecial
    onlyDigits = o.onlyDigits
  }

  static func fromDefaults(defaults: NSUserDefaults = NSUserDefaults.standardUserDefaults()) -> HashOptions {
    let options = HashOptions()
    options.length = defaults.integerForKey("length")
    options.requireDigit = defaults.boolForKey("requireDigit")
    options.requireSpecial = defaults.boolForKey("requireSpecial")
    options.requireMixed = defaults.boolForKey("requireMixed")
    options.onlyDigits = defaults.boolForKey("onlyDigits")
    options.forbidSpecial = defaults.boolForKey("forbidSpecial")
    return options
  }
  func saveDefaults(defaults: NSUserDefaults = NSUserDefaults.standardUserDefaults()) {
    let defaults = NSUserDefaults.standardUserDefaults()
    defaults.setBool(requireDigit, forKey: "requireDigit")
    defaults.setBool(requireSpecial, forKey: "requireSpecial")
    defaults.setBool(requireMixed, forKey: "requireMixed")
    defaults.setBool(onlyDigits, forKey: "onlyDigits")
    defaults.setBool(forbidSpecial, forKey: "forbidSpecial")
    defaults.setInteger(length, forKey: "length")
  }
}

class Hasher : NSObject {
  var options: HashOptions
  init(options: HashOptions) {
    self.options = options
  }

  func hash(tag tag: String, pass: String) -> String? {
    guard
      pass != "" && tag != "",
      let passData = pass.dataUsingEncoding(NSASCIIStringEncoding),
      let tagData = tag.dataUsingEncoding(NSASCIIStringEncoding) else {return nil}

    let outPtr = UnsafeMutablePointer<Void>.alloc(Int(CC_SHA1_DIGEST_LENGTH))
    CCHmac(CCHmacAlgorithm(kCCHmacAlgSHA1), passData.bytes, passData.length, tagData.bytes, tagData.length, outPtr)
    let outData = NSData(bytes: outPtr, length: Int(CC_SHA1_DIGEST_LENGTH))
    guard let b64 = NSString(data: outData.base64EncodedDataWithOptions([]), encoding: NSUTF8StringEncoding) as? String else {return nil}

    let seed = b64.utf8.reduce(0) {$0 + Int($1)} - (b64.characters.last == "=" ? Int("=".utf8.first!) : 0)
    let str = b64[b64.startIndex..<advance(b64.startIndex, options.length)]
    var utf = Array(str.utf8)

    if options.onlyDigits {
      convertToDigits(&utf, seed: seed)
    } else {
      if options.requireDigit {
        injectChar(&utf, at: 0, seed: seed, from: 0x30, length: 10)
      }
      if options.requireSpecial && !options.forbidSpecial {
        injectChar(&utf, at: 1, seed: seed, from: 0x21, length: 15)
      }
      if options.requireMixed {
        injectChar(&utf, at: 2, seed: seed, from: 0x41, length: 26)
        injectChar(&utf, at: 3, seed: seed, from: 0x61, length: 26)
      }
      if options.forbidSpecial {
        stripSpecial(&utf, seed: seed)
      }
    }

    var result = ""
    for x in utf { result += String(Character(UnicodeScalar(x))) }
    return result
  }
  func convertToDigits(inout utf: [UTF8.CodeUnit], seed: Int) {
    // logic error in original:
    var index = 0
    var digit = false
    for (i, x) in utf.enumerate() {
      if 0x30 <= x && x <= 0x39 {
        if !digit {index = i}
        digit = true
        continue
      }
      utf[i] = UTF8.CodeUnit(0x30 + (seed + Int(utf[index])) % 10)
      index = i + 1
      digit = false
    }

    // correct implementation:
    // for (i, x) in utf.enumerate() {
    //   if 0x30 <= x && x <= 0x39 {continue}
    //   utf[i] = UTF8.CodeUnit(0x30 + (seed + Int(x)) % 10)
    // }
  }
  var reservedChars: Int {get {return 4}}
  func injectChar(inout utf: [UTF8.CodeUnit], at offset: Int, seed: Int, from start: UTF8.CodeUnit, length: UTF8.CodeUnit) {
    let pos = (seed + offset) % utf.count
    for i in 0..<utf.count - reservedChars {
      let x = utf[(seed + reservedChars + i) % utf.count]
      if start <= x && x <= start + length {return}
    }
    utf[pos] = UTF8.CodeUnit(Int(start) + (seed + Int(utf[pos])) % Int(length))
  }
  func stripSpecial(inout utf: [UTF8.CodeUnit], seed: Int) {
    // TODO: very similar to convertToDigits, but awkwardly different
    // logic error in original:
    var index = 0
    var special = true
    for (i, x) in utf.enumerate() {
      if 0x30 <= x && x <= 0x39 || 0x41 <= x && x <= 0x5a || 0x61 <= x && x <= 0x7a {
        if special {index = i}
        special = false
        continue
      }
      utf[i] = UTF8.CodeUnit(0x41 + (seed + index) % 26)
      index = i + 1
      special = true
    }

    // correct implementation:
    // for (i, x) in utf.enumerate() {
    //   if 0x30 <= x && x <= 0x39 || 0x41 <= x && x <= 0x5a || 0x61 <= x && x <= 0x7a {continue}
    //   utf[i] = UTF8.CodeUnit(0x41 + (seed + Int(x)) % 26)
    // }
  }

}
