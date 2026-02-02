#!/usr/bin/env swift
// Generate TrainState app icon (1024×1024) directly into Assets.xcassets
// Run from project root: swift Scripts/GenerateAppIcon.swift

import AppKit
import Foundation

let size: CGFloat = 1024
let centerX = size / 2
let centerY = size / 2

let image = NSImage(size: NSSize(width: size, height: size))
image.lockFocus()

// Richer 3-color gradient (blue → violet → purple)
let gradient = NSGradient(colors: [
    NSColor(red: 0.20, green: 0.47, blue: 0.96, alpha: 1),
    NSColor(red: 0.45, green: 0.35, blue: 0.95, alpha: 1),
    NSColor(red: 0.55, green: 0.25, blue: 0.88, alpha: 1)
])!
gradient.draw(in: NSRect(origin: .zero, size: image.size), angle: 140)

// Dumbbell SF Symbol with soft shadow
let dumbbellRect = CGRect(
    x: centerX - 140,
    y: centerY - 80,
    width: 280,
    height: 200
)
if let dumbbell = NSImage(systemSymbolName: "dumbbell.fill", accessibilityDescription: nil) {
    let config = NSImage.SymbolConfiguration(pointSize: 200, weight: .semibold)
    let symbol = dumbbell.withSymbolConfiguration(config) ?? dumbbell
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.2)
    shadow.shadowOffset = NSSize(width: 0, height: -4)
    shadow.shadowBlurRadius = 10
    shadow.set()
    symbol.draw(in: dumbbellRect, from: .zero, operation: .sourceOver, fraction: 1)
    NSShadow().set()
}

// "TS" text with subtle shadow
let ts = "TS" as NSString
let font = NSFont.systemFont(ofSize: 96, weight: .bold)
let attrs: [NSAttributedString.Key: Any] = [
    .font: font,
    .foregroundColor: NSColor.white
]
let tsSize = ts.size(withAttributes: attrs)
let tsRect = CGRect(
    x: centerX - tsSize.width/2,
    y: centerY - 260 - tsSize.height/2,
    width: tsSize.width,
    height: tsSize.height
)
let textShadow = NSShadow()
textShadow.shadowColor = NSColor.black.withAlphaComponent(0.25)
textShadow.shadowOffset = NSSize(width: 0, height: -2)
textShadow.shadowBlurRadius = 4
textShadow.set()
ts.draw(in: tsRect, withAttributes: attrs)
NSShadow().set()

image.unlockFocus()

guard let tiff = image.tiffRepresentation,
      let bitmap = NSBitmapImageRep(data: tiff),
      let pngData = bitmap.representation(using: .png, properties: [:]) else {
    print("Failed to create PNG")
    exit(1)
}

let scriptDir = URL(fileURLWithPath: #file).deletingLastPathComponent()
let projectRoot = scriptDir.deletingLastPathComponent()
let outputURL = projectRoot
    .appendingPathComponent("TrainState")
    .appendingPathComponent("Assets.xcassets")
    .appendingPathComponent("AppIcon.appiconset")
    .appendingPathComponent("appstore.png")

do {
    try pngData.write(to: outputURL)
    // Ensure 1024×1024 (NSImage may produce 2x on Retina)
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/sips")
    process.arguments = ["-z", "1024", "1024", outputURL.path]
    try? process.run()
    process.waitUntilExit()
    print("Icon saved to: \(outputURL.path)")
} catch {
    print("Error: \(error)")
    exit(1)
}
