import UIKit

@objc
class LengthViewController: UITableViewController {
  static let lengths = [8,10,12,14,16,18,20,22,24,26]

  override func numberOfSectionsInTableView(tableView: UITableView) -> Int {return 1}
  override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    return LengthViewController.lengths.count
  }

  override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
    let cell = tableView.dequeueReusableCellWithIdentifier("cell", forIndexPath: indexPath)
    let length = LengthViewController.lengths[indexPath.indexAtPosition(1)]
    let current = ViewController.hashOptions.length
    cell.textLabel?.text = "\(length) Letters"
    cell.accessoryType = length == current ? UITableViewCellAccessoryType.Checkmark : .None
    return cell
  }

  override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
    let length = LengthViewController.lengths[indexPath.indexAtPosition(1)]
    ViewController.hashOptions.length = length
    for cell in tableView.visibleCells {
      cell.accessoryType = UITableViewCellAccessoryType.None
    }
    guard let cell = tableView.cellForRowAtIndexPath(indexPath) else {return}
    cell.setSelected(false, animated: true)
    cell.accessoryType = UITableViewCellAccessoryType.Checkmark
  }
}
