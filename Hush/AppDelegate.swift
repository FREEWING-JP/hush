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
  @IBOutlet var optionsSideConstraint: NSLayoutConstraint!
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
    self.window.contentView.addConstraint(optionsHeightConstraint)

    HotKeys.registerHotKey(UInt32(kVK_ANSI_H), modifiers: UInt32(cmdKey|optionKey|controlKey), block: {
      self.showDialog(self)
    })

    preferencesWindow.level = Int(CGWindowLevelForKey(CGWindowLevelKey.FloatingWindowLevelKey))

    // FIXME: doing this here sets the maximum width wider than necessary
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
      let appID = app.bundleIdentifier,

      let service = "Hush".dataUsingEncoding(NSUTF8StringEncoding),
      let account = appID.dataUsingEncoding(NSUTF8StringEncoding),
      let label = "Hush Tag: \(appName)".dataUsingEncoding(NSUTF8StringEncoding),
      let tag = tagField.stringValue.dataUsingEncoding(NSUTF8StringEncoding) else {return}

    var item: SecKeychainItem?
    if SecKeychainFindGenericPassword(nil, UInt32(service.length), UnsafePointer(service.bytes), UInt32(account.length), UnsafePointer(account.bytes), nil, nil, &item) != noErr {
      guard SecKeychainAddGenericPassword(nil, UInt32(service.length), UnsafePointer(service.bytes), UInt32(account.length), UnsafePointer(account.bytes), 0, nil, &item) == noErr else {return}
    }
    guard let it = item else {return}
    let options = rememberOptions ? NSKeyedArchiver.archivedDataWithRootObject(hashOptions) : NSData(bytes: nil, length: 0)

    var attrs = [
      SecKeychainAttribute(tag: SecItemAttr.LabelItemAttr.rawValue, length: UInt32(label.length), data: UnsafeMutablePointer(label.bytes)),
      SecKeychainAttribute(tag: SecItemAttr.GenericItemAttr.rawValue, length: UInt32(options.length), data: UnsafeMutablePointer(options.bytes)),
    ]
    var list = SecKeychainAttributeList(count: UInt32(attrs.count), attr: &attrs)
    SecKeychainItemModifyAttributesAndData(it, &list, rememberTag ? UInt32(tag.length) : 0, rememberTag ? tag.bytes : nil)
  }

  func loadOptionsForCurrentApp() -> (String?, HashOptions?) {
    let ws = NSWorkspace.sharedWorkspace()
    guard let appID = ws.menuBarOwningApplication?.bundleIdentifier else {return (nil, nil)}

    var result: AnyObject?
    let searchOptions = [
      kSecClass as String: kSecClassGenericPassword as String,
      kSecAttrAccount as String: appID,
      kSecAttrService as String: "Hush",
      kSecReturnData as String: true,
      kSecReturnAttributes as String: true,
    ]
    guard SecItemCopyMatching(searchOptions, &result) == noErr,
      let dict = result.flatMap({$0 as? Dictionary<String, AnyObject>}) else {return (nil, nil)}

    var tag: String?
    var hashOptions: HashOptions?
    if let tagData = dict[kSecValueData as String] as? NSData,
      let tagString = NSString(data: tagData, encoding: NSUTF8StringEncoding) {
        tag = tagString as String
    }
    if let optionsData = dict[kSecAttrGeneric as String] as? NSData,
      let options = NSKeyedUnarchiver.unarchiveObjectWithData(optionsData) as? HashOptions {
        hashOptions = options
    }
    return (tag, hashOptions)
  }

  func saveMasterPass() {
    guard NSUserDefaults.standardUserDefaults().boolForKey("rememberPass") else {return}
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
      }
    }
    if defaults.boolForKey("rememberPass") {
      // TODO: restore passphrase from keychain
    }
    if tagField.stringValue == "" {
      if defaults.boolForKey("guessTag") {
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
    }
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
