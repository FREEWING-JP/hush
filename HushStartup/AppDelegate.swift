import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
  func applicationDidFinishLaunching(aNotification: NSNotification) {
    let appPath = NSBundle.mainBundle().bundlePath.stringByDeletingLastPathComponent.stringByDeletingLastPathComponent.stringByDeletingLastPathComponent.stringByDeletingLastPathComponent
    if let executableURL = NSBundle(path: appPath)?.executableURL {
      do {
        try NSWorkspace.sharedWorkspace().launchApplicationAtURL(executableURL, options: NSWorkspaceLaunchOptions.Default, configuration: [
          NSWorkspaceLaunchConfigurationArguments: ["autostart"],
        ])
      } catch {}
    }
    NSApplication.sharedApplication().terminate(self)
  }
}

