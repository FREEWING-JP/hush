import Foundation

class Keychain {
  static func saveDataForApp(app: String, tag: String, options: HashOptions) {
    let defaults = NSUserDefaults.standardUserDefaults()
    let rememberTag = defaults.boolForKey("rememberTag")
    let rememberOptions = defaults.boolForKey("rememberOptions")
    guard rememberTag || rememberOptions else {return}

    let dict = NSMutableDictionary()
    if rememberTag {dict["tag"] = tag}
    if rememberOptions {dict["options"] = options.toJSON() as NSDictionary}
    let data: NSData
    do {
      data = try NSJSONSerialization.dataWithJSONObject(dict, options: [])
    } catch {return}

    if SecItemUpdate([
      kSecClass as String: kSecClassGenericPassword as String,
      kSecAttrService as String: "Hush Apps",
      kSecAttrAccount as String: app,
      kSecAttrSynchronizable as String: kSecAttrSynchronizableAny as String,
      ], [
        kSecValueData as String: data,
      ]) == noErr {return}

    var attrs = [
      kSecClass as String: kSecClassGenericPassword as String,
      kSecAttrService as String: "Hush Apps",
      kSecAttrAccount as String: app,
      kSecAttrLabel as String: "Hush (\(app))",
      kSecValueData as String: data,
      ] as [String: AnyObject]
    if defaults.boolForKey("synchronizeData") {
      attrs[kSecAttrSynchronizable as String] = true
      attrs[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlocked
    }
    SecItemAdd(attrs, nil)
  }
  static func loadDataForApp(app: String) -> (String?, HashOptions?) {
    var result: AnyObject?
    guard SecItemCopyMatching([
      kSecClass as String: kSecClassGenericPassword as String,
      kSecAttrService as String: "Hush Apps",
      kSecAttrAccount as String: app,
      kSecAttrSynchronizable as String: kSecAttrSynchronizableAny as String,
      kSecReturnData as String: true,
      ], &result) == noErr,
      let data = result as? NSData else {return (nil, nil)}

    do {
      guard let dict = try NSJSONSerialization.JSONObjectWithData(data, options: []) as? Dictionary<String, AnyObject> else {return (nil, nil)}
      let tag = dict["tag"] as? String
      let hashOptions = (dict["options"] as? Dictionary<String, AnyObject>).flatMap(HashOptions.init)
      return (tag, hashOptions)
    } catch {
      guard let dict = NSKeyedUnarchiver.unarchiveObjectWithData(data) as? Dictionary<String, AnyObject> else {return (nil, nil)}
      let tag = dict["tag"] as? String
      let hashOptions = dict["options"] as? HashOptions
      if let tag = tag, hashOptions = hashOptions {
        saveDataForApp(app, tag: tag, options: hashOptions)
      }
      return (tag, hashOptions)
    }
  }

  static func saveMasterPass(pass: String) {
    guard NSUserDefaults.standardUserDefaults().boolForKey("rememberPass"),
      let data = pass.dataUsingEncoding(NSUTF8StringEncoding) else {return}

    if SecItemUpdate([
      kSecClass as String: kSecClassGenericPassword as String,
      kSecAttrService as String: "Hush",
      kSecAttrAccount as String: "master",
      kSecAttrSynchronizable as String: kSecAttrSynchronizableAny as String,
      ], [
        kSecValueData as String: data,
      ]) == noErr {return}

    var attrs = [
      kSecClass as String: kSecClassGenericPassword as String,
      kSecAttrService as String: "Hush",
      kSecAttrAccount as String: "master",
      kSecAttrLabel as String: "Hush",
      kSecValueData as String: data as CFData,
      ] as [String: AnyObject]
    if NSUserDefaults.standardUserDefaults().boolForKey("synchronizeData") {
      attrs[kSecAttrSynchronizable as String] = true
      attrs[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlocked
    }
    SecItemAdd(attrs, nil)
  }
  static func loadMasterPass() -> String? {
    var result: AnyObject?
    guard SecItemCopyMatching([
      kSecClass as String: kSecClassGenericPassword as String,
      kSecAttrService as String: "Hush",
      kSecAttrAccount as String: "master",
      kSecAttrSynchronizable as String: kSecAttrSynchronizableAny as String,
      kSecReturnData as String: true,
      ], &result) == noErr,
      let data = result as? NSData,
      let pass = NSString(data: data, encoding: NSUTF8StringEncoding) else {return nil}
    return pass as String
  }
}
