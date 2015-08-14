import Cocoa

var defaultsContext = 0
let UIDefaults = ["revealTag", "revealHash"]
let allDefaults = ["enableLoginItem", "guessTag", "rememberTag", "rememberOptions", "rememberPass"] + UIDefaults

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
  @IBOutlet var window: NSPanel!
  @IBOutlet var preferencesWindow: NSPanel!

  @IBOutlet weak var tagField: NSTextField!
  @IBOutlet weak var passField: NSSecureTextField!
  @IBOutlet weak var hashField: NSSecureTextField!

  @IBOutlet weak var hashOptions: HashOptions!

  @IBOutlet weak var optionsButton: NSButton!
  @IBOutlet weak var submitButton: NSButton!

  @IBOutlet weak var optionsBox: NSBox!
  @IBOutlet var optionsBottomConstraint: NSLayoutConstraint!
  @IBOutlet var optionsMarginBottomConstraint: NSLayoutConstraint!
  @IBOutlet var optionsMarginTopConstraint: NSLayoutConstraint!
  var optionsSideConstraint: NSLayoutConstraint!
  var optionsHeightConstraint: NSLayoutConstraint!
  var optionsHeight: CGFloat = 0

  private var _optionsVisible = true
  private var animatingOptions = false
  private var hotKey: HotKey?

  @IBOutlet weak var securityButton: NSPopUpButton!
}

extension AppDelegate {
  func applicationDidFinishLaunching(aNotification: NSNotification) {
    let defaults = NSUserDefaults.standardUserDefaults()
    defaults.registerDefaults([
      "length": 16,
      "synchronizeData": true,
      "optionsVisible": false,
      "requireDigit": true,
      "requireSpecial": true,
      "requireMixed": true,
      "onlyDigits": false,
      "forbidSpecial": false,

      "enableLoginItem": true,
      "guessTag": true,
      "rememberTag": true,
      "rememberOptions": true,
      "rememberPass": false,
      "revealTag": true,
      "revealHash": false,
    ])
    for key in allDefaults {
      defaults.addObserver(self, forKeyPath: key, options: [], context: &defaultsContext)
    }
    updateLoginItem()

    // use a monospace font so you can tell the difference between l and I and O and 0 without pixel counting
    hashField.placeholderAttributedString = NSAttributedString(string: hashField.placeholderString!, attributes: [
      NSFontAttributeName: NSFont.systemFontOfSize(NSFont.systemFontSize()),
      NSForegroundColorAttributeName: NSColor.tertiaryLabelColor(),
    ])

    optionsHeight = optionsBox.contentView!.frame.height
    optionsHeightConstraint = NSLayoutConstraint(item: optionsBox.contentView!, attribute: NSLayoutAttribute.Height, relatedBy: NSLayoutRelation.Equal, toItem: nil, attribute: NSLayoutAttribute.NotAnAttribute, multiplier: 1, constant: optionsHeight)
    optionsSideConstraint = NSLayoutConstraint(item: optionsBox, attribute: NSLayoutAttribute.Leading, relatedBy: NSLayoutRelation.GreaterThanOrEqual, toItem: window.contentView, attribute: NSLayoutAttribute.Leading, multiplier: 1, constant: 20)
    self.window.contentView.addConstraint(optionsHeightConstraint)

    hotKey = HotKey.register(UInt32(kVK_ANSI_H), modifiers: UInt32(cmdKey|optionKey|controlKey), block: {
      self.showDialog(self)
    })

    preferencesWindow.level = Int(CGWindowLevelForKey(CGWindowLevelKey.FloatingWindowLevelKey))

    if let o = defaults.objectForKey("optionsVisible") as? NSNumber {setOptionsVisible(o.boolValue, animate: false)}
    applyUIPreferences(self)
    resetToDefaults(self)

    if !Process.arguments.contains("autostart") {
      showDialog(self)
    }
  }
  func applicationWillTerminate(aNotification: NSNotification) {
    let defaults = NSUserDefaults.standardUserDefaults()
    for key in UIDefaults {
      defaults.removeObserver(self, forKeyPath: key, context: &defaultsContext)
    }
    if let hk = hotKey {hk.unregister()}
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
    if let app = currentApp() {
      saveDataForApp(app)
    }
    saveMasterPass()
    hideDialog(self)
    guard let es = CGEventSourceCreate(CGEventSourceStateID.HIDSystemState) else {return}
    KeyboardEmulator.replaceText(hash, eventSource: es)
  }

  func saveDataForApp(app: String) {
    let defaults = NSUserDefaults.standardUserDefaults()
    let rememberTag = defaults.boolForKey("rememberTag")
    let rememberOptions = defaults.boolForKey("rememberOptions")
    guard rememberTag || rememberOptions else {return}

    let dict = NSMutableDictionary()
    if rememberTag {dict["tag"] = tagField.stringValue}
    if rememberOptions {dict["options"] = hashOptions}
    let data = NSKeyedArchiver.archivedDataWithRootObject(dict)

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
  func loadOptionsForApp(app: String) -> (String?, HashOptions?) {
    var result: AnyObject?
    guard SecItemCopyMatching([
      kSecClass as String: kSecClassGenericPassword as String,
      kSecAttrService as String: "Hush Apps",
      kSecAttrAccount as String: app,
      kSecAttrSynchronizable as String: kSecAttrSynchronizableAny as String,
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
  func loadMasterPass() -> String? {
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

    let app = currentApp()
    if rememberTag || rememberOptions, let app = app {
      let (tag, options) = loadOptionsForApp(app)
      if let tag = tag {
        tagField.stringValue = tag
      }
      if let options = options {
        hashOptions.setTo(options)
      } else {
        resetToDefaults(self)
      }
    }
    if defaults.boolForKey("rememberPass"),
      let pass = loadMasterPass() {
      passField.stringValue = pass
    }
    if tagField.stringValue == "" && defaults.boolForKey("guessTag"), let app = app {
      tagField.stringValue = app
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

  func currentApp() -> String? {
    let ws = NSWorkspace.sharedWorkspace()
    guard let app = ws.menuBarOwningApplication,
      let name = app.localizedName,
      let id = app.bundleIdentifier else {return nil}

    let base: String
    switch id {
    case "com.apple.Safari", "org.webkit.nightly.WebKit":
      let realName = id == "org.webkit.nightly.WebKit" ? "WebKit" : "Safari"
      if let url = NSAppleScript(source: "tell application \"\(realName)\" to return URL of front document")?.executeAndReturnError(nil).stringValue {
        base = appFromURL(url) ?? realName
      } else {
        base = realName
      }
    case "com.google.Chrome", "com.google.Chrome.canary":
      let realName = id == "com.google.Chrome.canary" ? "Google Chrome Canary" : "Google Chrome"
      if let url = NSAppleScript(source: "tell application \"\(realName)\" to return URL of active tab of front window")?.executeAndReturnError(nil).stringValue {
        base = appFromURL(url) ?? realName
      } else {
        base = realName
      }
    default:
      base = name
    }

    // just spaces
    // return base.lowercaseString.stringByReplacingOccurrencesOfString(" ", withString: " ")

    // kill EVERYTHING (except letters and numbers)
    let set = NSCharacterSet.alphanumericCharacterSet().invertedSet
    return "".join(base.lowercaseString.componentsSeparatedByCharactersInSet(set))
  }
  func appFromURL(url: String) -> String? {
    guard var components = NSURL(string: url)?.host?.componentsSeparatedByString(".") else {return nil}
    return components.count == 1 ? components.first : components[components.endIndex-2];
//    components.removeLast()
//    return ".".join(components);
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
    if animatingOptions {
      optionsButton.checked = optionsVisible
    } else {
      optionsVisible = !optionsVisible
    }
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
      animatingOptions = true
      NSAnimationContext.runAnimationGroup({context in
        self.updateOptionsConstraints(true)
        }) {
          self.updateOptionsConstraintsAfterAnimation()
          self.animatingOptions = false
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
    if context == &defaultsContext, let keyPath = keyPath {
      if (UIDefaults.contains(keyPath)) {
        applyUIPreferences(object)
      }
      if (keyPath == "enableLoginItem") {
        updateLoginItem()
      } else {
        updateSecurityButton()
      }
    } else {
      return super.observeValueForKeyPath(keyPath, ofObject: object, change: change, context: context)
    }
  }

  func updateLoginItem() {
    SMLoginItemSetEnabled("io.github.nathan.HushStartup", NSUserDefaults.standardUserDefaults().boolForKey("enableLoginItem") ? 1 : 0)
  }

  func updateSecurityButton() {
    let defaults = NSUserDefaults.standardUserDefaults()
    let opts = (
      defaults.boolForKey("guessTag"),
      defaults.boolForKey("rememberTag"),
      defaults.boolForKey("rememberOptions"),
      defaults.boolForKey("rememberPass"),
      defaults.boolForKey("revealTag"),
      defaults.boolForKey("revealHash")
    )
    securityButton.selectItemAtIndex(securityIndexForOpts(opts))
  }
  func securityIndexForOpts(opts: (Bool, Bool, Bool, Bool, Bool, Bool)) -> Int {
    switch opts {
    case (true, true, true, true, true, true): return 0
    case (true, true, true, false, true, false): return 1
    case (false, false, false, false, false, false): return 2
    default: return 3
    }
  }
  @IBAction func securityButtonSelect(sender: AnyObject) {
    let opts: (Bool, Bool, Bool, Bool, Bool, Bool)
    switch securityButton.indexOfSelectedItem {
    case 0: opts = (true, true, true, true, true, true)
    case 1: opts = (true, true, true, false, true, false)
    case 2: opts = (false, false, false, false, false, false)
    default: return
    }
    let defaults = NSUserDefaults.standardUserDefaults()
    defaults.setBool(opts.0, forKey: "guessTag")
    defaults.setBool(opts.1, forKey: "rememberTag")
    defaults.setBool(opts.2, forKey: "rememberOptions")
    defaults.setBool(opts.3, forKey: "rememberPass")
    defaults.setBool(opts.4, forKey: "revealTag")
    defaults.setBool(opts.5, forKey: "revealHash")
  }

  @IBAction func applyUIPreferences(sender: AnyObject?) {
    let defaults = NSUserDefaults.standardUserDefaults()
    tagField.secure = !defaults.boolForKey("revealTag")
    let revealHash = defaults.boolForKey("revealHash")
    hashField.secure = !revealHash
    hashField.font = revealHash ? NSFont.userFixedPitchFontOfSize(11) : NSFont.systemFontOfSize(NSFont.systemFontSize())
  }
}
