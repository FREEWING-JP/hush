import Cocoa
import ApplicationServices

var defaultsContext = 0
let UIDefaults = ["revealTag", "revealHash"]

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
  @IBOutlet var window: NSPanel!
  @IBOutlet var preferencesWindow: NSPanel!

  @IBOutlet weak var tagField: NSTextField!
  @IBOutlet weak var passField: NSSecureTextField!
  @IBOutlet weak var hashField: NSSecureTextField!

  @IBOutlet weak var lengthButton: NSPopUpButton!

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

  var eventHandler: AnyObject?

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
    eventHandler.map({NSEvent.removeMonitor($0)})
  }

  func windowDidBecomeMain(notification: NSNotification) {
    print(notification)
    if notification.object.flatMap({$0 as? NSPanel}) == preferencesWindow {
      print("yay")
    }
  }
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

  func monitor(event: NSEvent!) {
    print("\(event.charactersIgnoringModifiers) \(event.modifierFlags)")
    guard event.charactersIgnoringModifiers == "h" && event.modifierFlags.contains([NSEventModifierFlags.CommandKeyMask, NSEventModifierFlags.ControlKeyMask, NSEventModifierFlags.AlternateKeyMask]) else {return}
    showDialog(self)
  }

  @IBAction func showDialog(sender: AnyObject?) {
    // TODO: remember tags per app (by preference)
    let defaults = NSUserDefaults.standardUserDefaults()
    let shouldGuess = defaults.boolForKey("guessTag")

    if shouldGuess {
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
    if window.screen != NSScreen.mainScreen(),
      let scr = NSScreen.mainScreen()?.visibleFrame,
      let old = window.screen?.visibleFrame {
        let win = window.frame
        window.setFrame(win.rectByOffsetting(dx: scr.minX - old.minX, dy: scr.minX - old.minX), display: false)
    }
    window.makeFirstResponder(shouldGuess ? passField : hashField)
    window.makeKeyAndOrderFront(sender)
    NSApplication.sharedApplication().activateIgnoringOtherApps(true)
  }
  @IBAction func hideDialog(sender: AnyObject?) {
    NSApplication.sharedApplication().hide(sender)
    passField.stringValue = ""
    hashField.stringValue = ""
  }

  @IBAction func toggleOptions(sender: AnyObject?) {
    optionsVisible = !optionsVisible
  }

  override func validateMenuItem(menuItem: NSMenuItem) -> Bool {
    if menuItem.action == "toggleOptions:" {
      menuItem.title = optionsVisible ? "Hide Options" : "Show Options"
    }
    return true
//    return super.validateMenuItem(menuItem)
  }

  @IBAction func pressDefaultsButton(sender: AnyObject?) {
    guard let button = sender as? NSSegmentedControl else {return}
    if button.selectedSegment == 0 {
      updateDefaultsFromOptions(sender)
    } else {
      resetToDefaults(sender)
    }
  }

  private var _optionsVisible: Bool = true
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

  @IBAction func applyUIPreferences(sender: AnyObject?) {
    let defaults = NSUserDefaults.standardUserDefaults()
    tagField.secure = !defaults.boolForKey("revealTag")
    let revealHash = defaults.boolForKey("revealHash")
    hashField.secure = !revealHash
    hashField.font = revealHash ? NSFont.userFixedPitchFontOfSize(11) : NSFont.systemFontOfSize(NSFont.systemFontSize())
  }

  @IBAction func resetToDefaults(sender: AnyObject?) {
    let defaults = NSUserDefaults.standardUserDefaults()
    requireDigit.checked = defaults.boolForKey("requireDigit")
    requireSpecial.checked = defaults.boolForKey("requireSpecial")
    requireMixed.checked = defaults.boolForKey("requireMixed")
    onlyDigits.checked = defaults.boolForKey("onlyDigits")
    forbidSpecial.checked = defaults.boolForKey("forbidSpecial")
    lengthButton.selectItemWithTag(defaults.integerForKey("length"))
    updateOptionState()
  }
  @IBAction func updateDefaultsFromOptions(sender: AnyObject?) {
    let defaults = NSUserDefaults.standardUserDefaults()
    defaults.setBool(requireDigit.checked, forKey: "requireDigit")
    defaults.setBool(requireSpecial.checked, forKey: "requireSpecial")
    defaults.setBool(requireMixed.checked, forKey: "requireMixed")
    defaults.setBool(onlyDigits.checked, forKey: "onlyDigits")
    defaults.setBool(forbidSpecial.checked, forKey: "forbidSpecial")
    defaults.setInteger(lengthButton.selectedTag(), forKey: "length")
  }
  func updateOptionState() {
    requireDigit.enabled = !onlyDigits.checked
    requireSpecial.enabled = !onlyDigits.checked && !forbidSpecial.checked
    requireMixed.enabled = !onlyDigits.checked
    forbidSpecial.enabled = !onlyDigits.checked
  }
  @IBAction func updateOptions(sender: AnyObject?) {
    updateHash(sender)
    updateOptionState()
  }

  @IBAction func updateHash(sender: AnyObject?) {
    hashField.stringValue = generateHash() ?? ""
  }

  @IBAction func submit(sender: AnyObject?) {
    guard let hash = generateHash() else {
      hideDialog(self)
      return
    }
    saveOptionsForCurrentApp()
    hideDialog(self)
    guard let es = CGEventSourceCreate(CGEventSourceStateID.HIDSystemState) else {return}
    replaceText(hash, eventSource: es)
  }

  func saveOptionsForCurrentApp() {

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
}

extension AppDelegate {
  func generateHash() -> String? {
    let options = Hasher.Options(
      length: lengthButton.selectedTag(),
      requireDigit: requireDigit.checked,
      requireSpecial: requireSpecial.checked,
      requireMixed: requireMixed.checked,
      forbidSpecial: forbidSpecial.checked,
      onlyDigits: onlyDigits.checked
    )
    return Hasher(options: options).hash(tag: tagField.stringValue, pass: passField.stringValue)
  }
}

extension AppDelegate : NSTextFieldDelegate {
  override func controlTextDidChange(obj: NSNotification) {
    updateHash(obj.object)
  }
}

extension AppDelegate {
  func replaceText(text: String, eventSource es: CGEventSourceRef) {
    selectAll(eventSource: es)
    NSOperationQueue.mainQueue().addOperationWithBlock {self.typeText(text, eventSource: es)}
  }
  func typeText(text: String, eventSource es: CGEventSourceRef) {
    for char in text.utf16 {
      self.pressAndReleaseChar(char, eventSource: es)
    }
  }
  func deleteAll(eventSource es: CGEventSourceRef) {
    selectAll(eventSource: es)
    NSOperationQueue.mainQueue().addOperationWithBlock {
      self.pressAndReleaseKey(CGKeyCode(kVK_Delete), eventSource: es)
    }
  }
  func selectAll(eventSource es: CGEventSourceRef) {
    pressKey(CGKeyCode(kVK_Command), eventSource: es)
    pressAndReleaseKey(CGKeyCode(kVK_ANSI_A), flags: CGEventFlags_.Command, eventSource: es)
    releaseKey(CGKeyCode(kVK_Command), eventSource: es)
  }

  func pressAndReleaseChar(char: UniChar, flags: CGEventFlags_ = [], eventSource es: CGEventSourceRef) {
    pressChar(char, flags: flags, eventSource: es)
    releaseChar(char, flags: flags, eventSource: es)
  }
  func pressChar(var char: UniChar, keyDown: Bool = true, flags: CGEventFlags_ = [], eventSource es: CGEventSourceRef) {
    let event = CGEventCreateKeyboardEvent(es, 0, keyDown)
    if !flags.isEmpty {
      let flags = CGEventFlags(rawValue: UInt64(flags.rawValue))!
      CGEventSetFlags(event, flags)
    }
    CGEventKeyboardSetUnicodeString(event, 1, &char)
    CGEventPost(CGEventTapLocation.CGHIDEventTap, event)
  }
  func releaseChar(char: UniChar, flags: CGEventFlags_ = [], eventSource es: CGEventSourceRef) {
    pressChar(char, keyDown: false, flags: flags, eventSource: es)
  }

  func pressAndReleaseKey(key: CGKeyCode, flags: CGEventFlags_ = [], eventSource es: CGEventSourceRef) {
    pressKey(key, flags: flags, eventSource: es)
    releaseKey(key, flags: flags, eventSource: es)
  }
  func pressKey(key: CGKeyCode, keyDown: Bool = true, flags: CGEventFlags_ = [], eventSource es: CGEventSourceRef) {
    let event = CGEventCreateKeyboardEvent(es, key, keyDown)
    if !flags.isEmpty {
      let flags = CGEventFlags(rawValue: UInt64(flags.rawValue))!
      CGEventSetFlags(event, flags)
    }
    CGEventPost(CGEventTapLocation.CGHIDEventTap, event)
  }
  func releaseKey(key: CGKeyCode, flags: CGEventFlags_ = [], eventSource es: CGEventSourceRef) {
    pressKey(key, keyDown: false, flags: flags, eventSource: es)
  }
}
