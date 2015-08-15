import UIKit

@objc
class ViewController: UITableViewController, UITextFieldDelegate {
  static var hashOptions: HashOptions = HashOptions.fromDefaults()

  @IBOutlet weak var tagField: UITextField!
  @IBOutlet weak var passField: UITextField!
  @IBOutlet weak var hashField: UITextField!
  @IBOutlet weak var hashCell: UITableViewCell!

  override func viewDidLoad() {
    super.viewDidLoad()

    hashField.attributedPlaceholder = NSAttributedString(string: hashField.placeholder!, attributes: [NSFontAttributeName: UIFont.systemFontOfSize(16)])
  }

  override func viewWillAppear(animated: Bool) {
    super.viewWillAppear(animated)
    applyUIPreferences()
    updateHash(self)
  }

  override func viewDidAppear(animated: Bool) {
    super.viewDidAppear(animated)
    let field: UITextField
    if let text = tagField.text where !text.isEmpty {
      field = passField
    } else {
      field = tagField
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

  @IBAction func updateHash(sender: AnyObject?) {
    hashField.text = getHash() ?? ""
    hashCell.accessoryType = UITableViewCellAccessoryType.None
  }

  func reset() {
//    tagField.text = ""
    passField.text = ""
    updateHash(self)
  }

  func getHash() -> String? {
    guard let tag = tagField.text,
      pass = passField.text else {return nil}
    return Hasher(options: ViewController.hashOptions).hash(tag: tag, pass: pass)
  }

  func textFieldShouldReturn(textField: UITextField) -> Bool {
    switch textField {
    case tagField:
      passField.enabled = true
      passField.becomeFirstResponder()
    case passField:
      passField.resignFirstResponder()
      copyHash(textField)
    default: break
    }
    return false
  }

  override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
    guard let cell = tableView.cellForRowAtIndexPath(indexPath) else {return}

    if indexPath.indexAtPosition(0) == 0 {
      guard let field = cell.contentView.subviews.first as? UITextField else {return}
      field.enabled = true
      field.becomeFirstResponder()
    } else if indexPath.indexAtPosition(1) == 0 {
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
  }

  func applyUIPreferences() {
    let defaults = NSUserDefaults.standardUserDefaults()
    tagField.secureTextEntry = !defaults.boolForKey("revealTag")
    let revealHash = defaults.boolForKey("revealHash")
    hashField.secureTextEntry = !revealHash
    hashField.font = revealHash ? UIFont(name: "Menlo", size: 14) : UIFont.systemFontOfSize(16)
  }
}

