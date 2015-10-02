import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
  func applicationDidFinishLaunching(aNotification: NSNotification) {
    let appURL = NSBundle.mainBundle().bundleURL.URLByDeletingLastPathComponent?.URLByDeletingLastPathComponent?.URLByDeletingLastPathComponent?.URLByDeletingLastPathComponent
    if let appURL = appURL, executableURL = NSBundle(URL: appURL)?.executableURL {
      do {
        try NSWorkspace.sharedWorkspace().launchApplicationAtURL(executableURL, options: NSWorkspaceLaunchOptions.Default, configuration: [
          NSWorkspaceLaunchConfigurationArguments: ["autostart"],
        ])
      } catch {}
    }
    NSApplication.sharedApplication().terminate(self)
  }
}

