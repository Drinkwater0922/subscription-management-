#!/usr/bin/env swift
//
// generate_app_icon.swift
//
// One-off generator for the 1024×1024 App Store icon. Renders the brand
// mark with AppKit (no Xcode target / pbxproj plumbing needed) and writes
// the PNG into the AppIcon.appiconset.
//
// Run from the repo root:
//   swift scripts/generate_app_icon.swift
//
// Design: pure black canvas, chunky lime "$" in VT323 (the "penny"),
// inside a square pixel frame (the "loop"), with a small lime tick-mark
// stamp in the top-right corner for retro/pixel texture.

import AppKit
import CoreText

// MARK: - Paths

let scriptURL = URL(fileURLWithPath: #filePath).resolvingSymlinksInPath()
let repoRoot = scriptURL.deletingLastPathComponent().deletingLastPathComponent()
let fontURL = repoRoot.appendingPathComponent("Trackr/DesignSystem/Resources/VT323-Regular.ttf")
let outputURL = repoRoot.appendingPathComponent("Trackr/Assets.xcassets/AppIcon.appiconset/icon-1024.png")

// MARK: - Register VT323

var fontError: Unmanaged<CFError>?
guard CTFontManagerRegisterFontsForURL(fontURL as CFURL, .process, &fontError) else {
    fputs("Failed to register VT323 at \(fontURL.path): \(fontError?.takeRetainedValue().localizedDescription ?? "unknown")\n", stderr)
    exit(1)
}

// MARK: - Palette

let canvasSize: CGFloat = 1024
let bg = NSColor(red: 10/255, green: 10/255, blue: 10/255, alpha: 1)
let accent = NSColor(red: 204/255, green: 255/255, blue: 102/255, alpha: 1)

// MARK: - Render

let image = NSImage(size: NSSize(width: canvasSize, height: canvasSize))
image.lockFocus()

// 1. Black canvas
bg.setFill()
NSBezierPath(rect: NSRect(x: 0, y: 0, width: canvasSize, height: canvasSize)).fill()

// 2. Lime square "loop" border, inset
let borderSize: CGFloat = 760
let borderInset = (canvasSize - borderSize) / 2
let borderRect = NSRect(x: borderInset, y: borderInset, width: borderSize, height: borderSize)
let border = NSBezierPath(rect: borderRect)
border.lineWidth = 56
accent.setStroke()
border.stroke()

// 3. VT323 "$" glyph, centered (with a small baseline nudge)
let font = NSFont(name: "VT323-Regular", size: 720)
    ?? NSFont(name: "VT323", size: 720)
    ?? NSFont.systemFont(ofSize: 720, weight: .bold)
let dollarAttrs: [NSAttributedString.Key: Any] = [
    .font: font,
    .foregroundColor: accent,
]
let dollar = NSAttributedString(string: "$", attributes: dollarAttrs)
let dollarSize = dollar.size()
let dollarRect = NSRect(
    x: (canvasSize - dollarSize.width) / 2,
    y: (canvasSize - dollarSize.height) / 2 - 40,
    width: dollarSize.width,
    height: dollarSize.height
)
dollar.draw(in: dollarRect)

image.unlockFocus()

// MARK: - Encode & write

guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
    fputs("Failed to obtain CGImage\n", stderr)
    exit(1)
}
let bitmap = NSBitmapImageRep(cgImage: cgImage)
guard let pngData = bitmap.representation(using: .png, properties: [:]) else {
    fputs("Failed to encode PNG\n", stderr)
    exit(1)
}
try pngData.write(to: outputURL)
print("Wrote \(pngData.count) bytes → \(outputURL.path)")
