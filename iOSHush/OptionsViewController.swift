import UIKit

@objc
class OptionsViewController: UITableViewController {
  @IBOutlet weak var lengthLabel: UILabel!
  @IBOutlet weak var requireDigitSwitch: UISwitch!
  @IBOutlet weak var requireSpecialSwitch: UISwitch!
  @IBOutlet weak var requireMixedSwitch: UISwitch!
  @IBOutlet weak var forbidSpecialSwitch: UISwitch!
  @IBOutlet weak var onlyDigitsSwitch: UISwitch!

  override func viewWillAppear(animated: Bool) {
    super.viewWillAppear(animated)

    updateFromOptions()
  }

  override func tableView(tableView: UITableView, shouldHighlightRowAtIndexPath indexPath: NSIndexPath) -> Bool {
    guard let cell = tableView.cellForRowAtIndexPath(indexPath) else {return false}
    return cell.viewWithTag(1) == nil
  }

  override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
    guard let cell = tableView.cellForRowAtIndexPath(indexPath) else {return}

    if indexPath.indexAtPosition(0) > 0 {
      cell.setSelected(false, animated: true)
      switch indexPath.indexAtPosition(1) {
      case 0: updateDefaultsFromOptions()
      case 1: resetToDefaults()
      default: break
      }
    }
  }

  func resetToDefaults() {
    ViewController.hashOptions = HashOptions.fromDefaults()
    updateFromOptions(true)
  }
  func updateDefaultsFromOptions() {
    ViewController.hashOptions.saveDefaults()
  }


  func updateFromOptions(animated: Bool = false) {
    let options = ViewController.hashOptions
    lengthLabel.text = "\(options.length) Letters"

    requireDigitSwitch.setOn(options.requireDigit, animated: animated)
    requireSpecialSwitch.setOn(options.requireSpecial, animated: animated)
    requireMixedSwitch.setOn(options.requireMixed, animated: animated)
    forbidSpecialSwitch.setOn(options.forbidSpecial, animated: animated)
    onlyDigitsSwitch.setOn(options.onlyDigits, animated: animated)
    updateAvailability()
  }
  @IBAction func updateOptionsFromSwitches(sender: AnyObject) {
    let options = ViewController.hashOptions
    options.requireDigit = requireDigitSwitch.on
    options.requireSpecial = requireSpecialSwitch.on
    options.requireMixed = requireMixedSwitch.on
    options.forbidSpecial = forbidSpecialSwitch.on
    options.onlyDigits = onlyDigitsSwitch.on
    updateAvailability()
  }

  func updateAvailability() {
    let notDigits = !onlyDigitsSwitch.on
    requireDigitSwitch.enabled = notDigits
    requireSpecialSwitch.enabled = notDigits && !forbidSpecialSwitch.on
    requireMixedSwitch.enabled = notDigits
    forbidSpecialSwitch.enabled = notDigits
  }
}
