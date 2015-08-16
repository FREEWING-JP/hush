import UIKit

@objc
class ViewController: UITableViewController, UITextFieldDelegate {
  static var hashOptions: HashOptions = HashOptions.fromDefaults()
  static var configuredOptions: HashOptions = hashOptions

  @IBOutlet weak var appField: UITextField!
  @IBOutlet weak var tagField: UITextField!
  @IBOutlet weak var passField: UITextField!
  @IBOutlet weak var hashField: UITextField!
  @IBOutlet weak var hashCell: UITableViewCell!

  override func viewDidLoad() {
    super.viewDidLoad()

    hashField.attributedPlaceholder = NSAttributedString(string: hashField.placeholder!, attributes: [NSFontAttributeName: UIFont.systemFontOfSize(16)])
    reset()
  }

  override func viewWillAppear(animated: Bool) {
    super.viewWillAppear(animated)
    applyUIPreferences()
    updateHash(self)
  }

  override func viewDidAppear(animated: Bool) {
    super.viewDidAppear(animated)
    let field: UITextField
    if let app = appField.text, pass = passField.text where !app.isEmpty && pass.isEmpty {
      field = passField
    } else {
      field = appField
    }
    field.enabled = true
    field.becomeFirstResponder()
  }

  override func didReceiveMemoryWarning() {
    super.didReceiveMemoryWarning()
    // Dispose of any resources that can be recreated.
  }

  @IBAction func blurField(sender: AnyObject) {
    guard let field = sender as? UITextField else {return}
    field.enabled = false
  }

  @IBAction func appChange(sender: AnyObject) {
    guard let app = appField.text.map(Hasher.formatTag) else {return}
    let (tag, options) = Keychain.loadDataForApp(app)
    tagField.text = tag ?? app
    if let opts = options {
      ViewController.configuredOptions = opts.copy() as! HashOptions
    }
    ViewController.hashOptions.setTo(options ?? ViewController.configuredOptions)
    updateHash(sender)
  }
  @IBAction func updateHash(sender: AnyObject?) {
    hashField.text = getHash() ?? ""
    hashCell.accessoryType = UITableViewCellAccessoryType.None
  }

  func reset() {
    let defaults = NSUserDefaults.standardUserDefaults()
    if defaults.boolForKey("rememberPass"),
      let pass = Keychain.loadMasterPass() {
        passField.text = pass
    } else {
      passField.text = ""
    }
    updateHash(self)
  }

  @IBAction func bumpTag(sender: AnyObject) {
    guard let tag = tagField.text else {return}
    tagField.text = Hasher.bumpTag(tag)
  }

  func getHash() -> String? {
    guard let tag = tagField.text,
      pass = passField.text else {return nil}
    return Hasher(options: ViewController.hashOptions).hash(tag: tag, pass: pass)
  }

  func textFieldShouldReturn(textField: UITextField) -> Bool {
    switch textField {
    case appField:
      passField.enabled = true
      passField.becomeFirstResponder()
    case passField, tagField:
      textField.resignFirstResponder()
      copyHash(textField)
    default: break
    }
    return false
  }

  override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
    guard let cell = tableView.cellForRowAtIndexPath(indexPath) else {return}

    if let field = cell.viewWithTag(1) as? UITextField {
      field.enabled = true
      field.becomeFirstResponder()
    } else if cell.viewWithTag(2) != nil {
      copyHash(cell)
    } else {
      return
    }
    cell.setSelected(false, animated: false)
  }

  @IBAction func copyHash(sender: AnyObject?) {
    guard let hash = getHash() else {return}
    UIPasteboard.generalPasteboard().string = hash
    hashCell.accessoryType = UITableViewCellAccessoryType.Checkmark
    passField.resignFirstResponder()

    let defaults = NSUserDefaults.standardUserDefaults()
    if defaults.boolForKey("rememberPass"),
      let pass = passField.text {
        Keychain.saveMasterPass(pass)
    }
    if defaults.boolForKey("rememberOptions"),
      let app = appField.text,
      let tag = tagField.text {
        Keychain.saveDataForApp(Hasher.formatTag(app), tag: tag, options: ViewController.hashOptions)
    }
  }

  func applyUIPreferences() {
    let defaults = NSUserDefaults.standardUserDefaults()
    tagField.secureTextEntry = !defaults.boolForKey("revealTag")
    let revealHash = defaults.boolForKey("revealHash")
    hashField.secureTextEntry = !revealHash
    hashField.font = revealHash ? UIFont(name: "Menlo", size: 14) : UIFont.systemFontOfSize(16)
  }
}

