// For a probe only, removed before its pull request merges: does an
// AppleInterfaceThemeChangedNotification posted the way the IDE tour posts
// it reach an observer? argv[1] "foundation" (no NSApplication) or "appkit"
// (an NSApplication, inactive, as the engine is on a CI runner).
import AppKit
let mode = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "foundation"
var got = 0
let name = NSNotification.Name("AppleInterfaceThemeChangedNotification")
if mode == "appkit" { _ = NSApplication.shared; NSApp.setActivationPolicy(.regular) }
DistributedNotificationCenter.default().addObserver(forName: name, object: nil, queue: nil) { n in
    got += 1
    print("\(mode): GOT \(n.name.rawValue) object=\(String(describing: n.object))")
}
func post(_ how: String) {
    let p = Process()
    p.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
    p.arguments = ["-l", "JavaScript", "-e", how]
    try? p.run(); p.waitUntilExit()
    print("\(mode): osascript status \(p.terminationStatus)")
}
DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
    post("ObjC.import('Foundation'); $.NSDistributedNotificationCenter.defaultCenter.postNotificationNameObjectUserInfoDeliverImmediately('AppleInterfaceThemeChangedNotification', null, null, true)")
}
DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
    print("\(mode): after the tour's post: \(got)")
    DistributedNotificationCenter.default().postNotificationName(name, object: nil, userInfo: nil, deliverImmediately: true)
}
DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
    print("\(mode): after a post from this process too: \(got)")
    exit(0)
}
if mode == "appkit" { NSApp.run() } else { RunLoop.main.run() }
