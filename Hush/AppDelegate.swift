import Cocoa

var defaultsContext = 0
let UIDefaults = ["revealTag", "revealHash"]

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
  @IBOutlet var window: NSPanel!
  @IBOutlet var preferencesWindow: NSPanel!

  @IBOutlet weak var tagField: NSTextField!
  @IBOutlet weak var passField: NSSecureTextField!
  @IBOutlet weak var hashField: NSSecureTextField!

  @IBOutlet weak var hashOptions: HashOptions!

  @IBOutlet weak var requireDigit: NSButton!
  @IBOutlet weak var requireSpecial: NSButton!
  @IBOutlet weak var requireMixed: NSButton!

  @IBOutlet weak var forbidSpecial: NSButton!
  @IBOutlet weak var onlyDigits: NSButton!

  @IBOutlet weak var optionsButton: NSButton!
  @IBOutlet weak var submitButton: NSButton!

  @IBOutlet weak var optionsBox: NSBox!
  @IBOutlet var optionsBottomConstraint: NSLayoutConstraint!
  @IBOutlet var optionsMarginBottomConstraint: NSLayoutConstraint!
  @IBOutlet var optionsMarginTopConstraint: NSLayoutConstraint!
  var optionsSideConstraint: NSLayoutConstraint!
  var optionsHeightConstraint: NSLayoutConstraint!
  var optionsHeight: CGFloat = 0

  private var _optionsVisible: Bool = true
}

extension AppDelegate {
  func applicationDidFinishLaunching(aNotification: NSNotification) {
    let defaults = NSUserDefaults.standardUserDefaults()
    defaults.registerDefaults([
      "length": 16,
      "optionsVisible": false,
      "requireDigit": true,
      "requireSpecial": true,
      "requireMixed": true,
      "onlyDigits": false,
      "forbidSpecial": false,
      "guessTag": true,
      "rememberTag": true,
      "rememberOptions": true,
      "rememberPass": false,
      "revealTag": true,
      "revealHash": false,
    ])
    for key in UIDefaults {
      defaults.addObserver(self, forKeyPath: key, options: [], context: &defaultsContext)
    }
    // TODO: set login item on first run / add a preference for this

    // use a monospace font so you can tell the difference between l and I and O and 0 without pixel counting
    hashField.placeholderAttributedString = NSAttributedString(string: hashField.placeholderString!, attributes: [
      NSFontAttributeName: NSFont.systemFontOfSize(NSFont.systemFontSize()),
      NSForegroundColorAttributeName: NSColor.tertiaryLabelColor(),
    ])

    optionsHeight = optionsBox.contentView!.frame.height
    optionsHeightConstraint = NSLayoutConstraint(item: optionsBox.contentView!, attribute: NSLayoutAttribute.Height, relatedBy: NSLayoutRelation.Equal, toItem: nil, attribute: NSLayoutAttribute.NotAnAttribute, multiplier: 1, constant: optionsHeight)
    optionsSideConstraint = NSLayoutConstraint(item: optionsBox, attribute: NSLayoutAttribute.Leading, relatedBy: NSLayoutRelation.GreaterThanOrEqual, toItem: window.contentView, attribute: NSLayoutAttribute.Leading, multiplier: 1, constant: 20)
    self.window.contentView.addConstraint(optionsHeightConstraint)

    HotKeys.registerHotKey(UInt32(kVK_ANSI_H), modifiers: UInt32(cmdKey|optionKey|controlKey), block: {
      self.showDialog(self)
    })

    preferencesWindow.level = Int(CGWindowLevelForKey(CGWindowLevelKey.FloatingWindowLevelKey))

    if let o = defaults.objectForKey("optionsVisible") as? NSNumber {setOptionsVisible(o.boolValue, animate: false)}
    applyUIPreferences(self)
    resetToDefaults(self)
    window.layoutIfNeeded()
    showDialog(self)
  }
  func applicationWillTerminate(aNotification: NSNotification) {
    let defaults = NSUserDefaults.standardUserDefaults()
    for key in UIDefaults {
      defaults.removeObserver(self, forKeyPath: key, context: &defaultsContext)
    }
  }
}

extension AppDelegate {
  @IBAction func updateHash(sender: AnyObject?) {
    hashField.stringValue = generateHash() ?? ""
  }
  func generateHash() -> String? {
    return Hasher(options: hashOptions).hash(tag: tagField.stringValue, pass: passField.stringValue)
  }

  @IBAction func submit(sender: AnyObject?) {
    guard let hash = generateHash() else {
      hideDialog(self)
      return
    }
    saveDataForCurrentApp()
    saveMasterPass()
    hideDialog(self)
    guard let es = CGEventSourceCreate(CGEventSourceStateID.HIDSystemState) else {return}
    KeyboardEmulator.replaceText(hash, eventSource: es)
  }

  func saveDataForCurrentApp() {
    let defaults = NSUserDefaults.standardUserDefaults()
    let rememberTag = defaults.boolForKey("rememberTag")
    let rememberOptions = defaults.boolForKey("rememberOptions")
    guard rememberTag || rememberOptions else {return}

    let ws = NSWorkspace.sharedWorkspace()
    guard
      let app = ws.menuBarOwningApplication,
      let appName = app.localizedName,
      let appID = app.bundleIdentifier else {return}

    let dict = NSMutableDictionary()
    if rememberTag {dict["tag"] = tagField.stringValue}
    if rememberOptions {dict["options"] = hashOptions}
    let data = NSKeyedArchiver.archivedDataWithRootObject(dict)

    if SecItemUpdate([
      kSecClass as String: kSecClassGenericPassword as String,
      kSecAttrService as String: "Hush Apps",
      kSecAttrAccount as String: appID,
      ], [
      kSecValueData as String: data,
      ]) == noErr {return}

    SecItemAdd([
      kSecClass as String: kSecClassGenericPassword as String,
      kSecAttrService as String: "Hush Apps",
      kSecAttrAccount as String: appID,
      kSecAttrLabel as String: "Hush (\(appName))",
      kSecValueData as String: data,
    ], nil)
  }
  func loadOptionsForCurrentApp() -> (String?, HashOptions?) {
    let ws = NSWorkspace.sharedWorkspace()
    guard let appID = ws.menuBarOwningApplication?.bundleIdentifier else {return (nil, nil)}

    var result: AnyObject?
    guard SecItemCopyMatching([
      kSecClass as String: kSecClassGenericPassword as String,
      kSecAttrService as String: "Hush Apps",
      kSecAttrAccount as String: appID,
      kSecReturnData as String: true,
      ], &result) == noErr,
      let data = result as? NSData,
      let dict = NSKeyedUnarchiver.unarchiveObjectWithData(data) else {return (nil, nil)}

    let tag = dict["tag"] as? String
    let hashOptions = dict["options"] as? HashOptions
    return (tag, hashOptions)
  }

  func saveMasterPass() {
    guard NSUserDefaults.standardUserDefaults().boolForKey("rememberPass"),
      let data = passField.stringValue.dataUsingEncoding(NSUTF8StringEncoding) else {return}

    if SecItemUpdate([
      kSecClass as String: kSecClassGenericPassword as String,
      kSecAttrService as String: "Hush",
      kSecAttrAccount as String: "master",
    ], [
      kSecValueData as String: data,
    ]) == noErr {return}

    SecItemAdd([
      kSecClass as String: kSecClassGenericPassword as String,
      kSecAttrService as String: "Hush",
      kSecAttrAccount as String: "master",
      kSecAttrLabel as String: "Hush",
      kSecValueData as String: data as CFData,
    ], nil)
  }
  func loadMasterPass() -> String? {
    var result: AnyObject?
    guard SecItemCopyMatching([
      kSecClass as String: kSecClassGenericPassword as String,
      kSecAttrService as String: "Hush",
      kSecAttrAccount as String: "master",
      kSecReturnData as String: true,
      ], &result) == noErr,
      let data = result as? NSData,
      let pass = NSString(data: data, encoding: NSUTF8StringEncoding) else {return nil}
    return pass as String
  }
}

extension AppDelegate {
  func windowShouldClose(sender: AnyObject) -> Bool {
    if sender as? NSPanel == window {
      hideDialog(sender)
      return false
    }
    return true
  }
  func applicationWillResignActive(notification: NSNotification) {
    hideDialog(self)
  }

  @IBAction func showDialog(sender: AnyObject?) {
    let defaults = NSUserDefaults.standardUserDefaults()
    let rememberTag = defaults.boolForKey("rememberTag")
    let rememberOptions = defaults.boolForKey("rememberOptions")

    if rememberTag || rememberOptions {
      let (tag, options) = loadOptionsForCurrentApp()
      if let tag = tag {
        tagField.stringValue = tag
      }
      if let options = options {
        hashOptions.setTo(options)
        updateOptionState()
      } else {
        resetToDefaults(self)
      }
    }
    if defaults.boolForKey("rememberPass"),
      let pass = loadMasterPass() {
      passField.stringValue = pass
    }
    if tagField.stringValue == "" && defaults.boolForKey("guessTag") {
      let ws = NSWorkspace.sharedWorkspace()
      if let app = ws.menuBarOwningApplication,
        let name = app.localizedName {
          // just spaces
          // let tag = name.lowercaseString.stringByReplacingOccurrencesOfString(" ", withString: " ")

          // kill EVERYTHING (except letters and numbers)
          let set = NSCharacterSet.alphanumericCharacterSet().invertedSet
          let tag = (name.lowercaseString.componentsSeparatedByCharactersInSet(set) as NSArray).componentsJoinedByString("")
          tagField.stringValue = tag
      }
    }
    updateHash(self)
    if window.screen != NSScreen.mainScreen(),
      let scr = NSScreen.mainScreen()?.visibleFrame,
      let old = window.screen?.visibleFrame {
        let win = window.frame
        window.setFrame(win.rectByOffsetting(dx: scr.minX - old.minX, dy: scr.minX - old.minX), display: false)
    }
    window.makeFirstResponder(tagField.stringValue == "" ? tagField : passField)
    window.makeKeyAndOrderFront(sender)
    NSApplication.sharedApplication().activateIgnoringOtherApps(true)
  }
  @IBAction func hideDialog(sender: AnyObject?) {
    NSApplication.sharedApplication().hide(sender)
    passField.stringValue = ""
    hashField.stringValue = ""
    tagField.stringValue = ""
  }

}

extension AppDelegate {
  override func validateMenuItem(menuItem: NSMenuItem) -> Bool {
    if menuItem.action == "toggleOptions:" {
      menuItem.title = optionsVisible ? "Hide Options" : "Show Options"
    }
    return true
  }
}

extension AppDelegate {
  @IBAction func toggleOptions(sender: AnyObject?) {
    optionsVisible = !optionsVisible
  }

  var optionsVisible: Bool {
    get {return _optionsVisible}
    set {setOptionsVisible(newValue)}
  }
  func setOptionsVisible(value: Bool, animate: Bool = true) {
    guard value != _optionsVisible else {return}

    _optionsVisible = value
    optionsButton.checked = value
    NSUserDefaults.standardUserDefaults().setBool(value, forKey: "optionsVisible")

    if (animate) {
      // TODO don't do this while animating
      NSAnimationContext.runAnimationGroup({context in
        self.updateOptionsConstraints(true)
        }) {
          self.updateOptionsConstraintsAfterAnimation()
      }
    } else {
      self.updateOptionsConstraints(false)
      self.updateOptionsConstraintsAfterAnimation()
    }
  }

  func updateOptionsConstraints(animate: Bool) {
    if !optionsVisible {
      optionsBox.contentView?.removeConstraint(optionsBottomConstraint)
      window.contentView.removeConstraint(optionsSideConstraint)
    }
    let animator: (NSLayoutConstraint) -> NSLayoutConstraint = animate ? {$0.animator()} : {$0}
    animator(optionsHeightConstraint).constant = optionsVisible ? optionsHeight : 0
    animator(optionsMarginTopConstraint).constant = optionsVisible ? 20 : 4
    animator(optionsMarginBottomConstraint).constant = optionsVisible ? 20 : 4
    if (optionsVisible) {
      optionsBox.hidden = false
      window.contentView.addConstraint(optionsSideConstraint)
    }
  }
  func updateOptionsConstraintsAfterAnimation() {
    if optionsVisible {
      optionsBox.contentView?.addConstraint(optionsBottomConstraint)
    } else {
      optionsBox.hidden = true
    }
  }
}

extension AppDelegate {
  @IBAction func resetToDefaults(sender: AnyObject?) {
    let defaults = NSUserDefaults.standardUserDefaults()
    hashOptions.length = defaults.integerForKey("length")
    hashOptions.requireDigit = defaults.boolForKey("requireDigit")
    hashOptions.requireSpecial = defaults.boolForKey("requireSpecial")
    hashOptions.requireMixed = defaults.boolForKey("requireMixed")
    hashOptions.onlyDigits = defaults.boolForKey("onlyDigits")
    hashOptions.forbidSpecial = defaults.boolForKey("forbidSpecial")
    updateOptionState()
  }
  @IBAction func updateDefaultsFromOptions(sender: AnyObject?) {
    let defaults = NSUserDefaults.standardUserDefaults()
    defaults.setBool(hashOptions.requireDigit, forKey: "requireDigit")
    defaults.setBool(hashOptions.requireSpecial, forKey: "requireSpecial")
    defaults.setBool(hashOptions.requireMixed, forKey: "requireMixed")
    defaults.setBool(hashOptions.onlyDigits, forKey: "onlyDigits")
    defaults.setBool(hashOptions.forbidSpecial, forKey: "forbidSpecial")
    defaults.setInteger(hashOptions.length, forKey: "length")
  }

  @IBAction func updateOptions(sender: AnyObject?) {
    updateHash(sender)
    updateOptionState()
  }
  func updateOptionState() {
    requireDigit.enabled = !hashOptions.onlyDigits
    requireSpecial.enabled = !hashOptions.onlyDigits && !hashOptions.forbidSpecial
    requireMixed.enabled = !hashOptions.onlyDigits
    forbidSpecial.enabled = !hashOptions.onlyDigits
  }

  @IBAction func pressDefaultsButton(sender: AnyObject?) {
    guard let button = sender as? NSSegmentedControl else {return}
    if button.selectedSegment == 0 {
      updateDefaultsFromOptions(sender)
    } else {
      resetToDefaults(sender)
    }
  }
}

extension AppDelegate : NSTextFieldDelegate {
  override func controlTextDidChange(obj: NSNotification) {
    updateHash(obj.object)
  }
}

extension AppDelegate {
  override func observeValueForKeyPath(keyPath: String?, ofObject object: AnyObject?, change: [String : AnyObject]?, context: UnsafeMutablePointer<Void>) {
    if context == &defaultsContext {
      applyUIPreferences(object)
    } else {
      return super.observeValueForKeyPath(keyPath, ofObject: object, change: change, context: context)
    }
  }

  @IBAction func applyUIPreferences(sender: AnyObject?) {
    let defaults = NSUserDefaults.standardUserDefaults()
    tagField.secure = !defaults.boolForKey("revealTag")
    let revealHash = defaults.boolForKey("revealHash")
    hashField.secure = !revealHash
    hashField.font = revealHash ? NSFont.userFixedPitchFontOfSize(11) : NSFont.systemFontOfSize(NSFont.systemFontSize())
  }
}
