import AppKit
import Foundation

let argv = CommandLine.arguments
if argv.count < 2 { fputs("Missing application path\n", stderr); exit(2) }
let appURL = URL(fileURLWithPath: argv[1], isDirectory: true).standardizedFileURL
if let resolved = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "dev.aichecker.localapp") {
    print("LAUNCH_SERVICES_RESOLVED: \(resolved.path)")
    print("LAUNCH_SERVICES_POINTS_TO_INSTALLED: \(resolved.standardizedFileURL == appURL)")
} else {
    print("LAUNCH_SERVICES_RESOLVED: NONE")
}
let icon = NSWorkspace.shared.icon(forFile: appURL.path)
if let tiff = icon.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff),
   let png = rep.representation(using: .png, properties: [:]) {
    let out = FileManager.default.temporaryDirectory.appendingPathComponent("ai-checker-os-resolved-icon.png")
    try? png.write(to: out, options: .atomic)
    print("APPKIT_ICON_RENDERED: YES")
    print("APPKIT_ICON_PREVIEW: \(out.path)")
} else {
    print("APPKIT_ICON_RENDERED: NO")
}
