#!/usr/bin/env swift
//
// generate_app_icon.swift
//
// One-off generator for the 1024×1024 App Store icon. Renders the brand
// mark with Core Graphics directly (controls exact pixel dimensions and
// strips alpha — both required by App Store Connect) and writes the PNG
// into the AppIcon.appiconset.
//
// Run from the repo root:
//   swift scripts/generate_app_icon.swift
//
// Design: pure black canvas, chunky lime "$" in VT323 (the "penny"),
// inside a square pixel frame (the "loop").

import AppKit
import CoreText
import ImageIO
import UniformTypeIdentifiers

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

// MARK: - Palette + canvas

let canvasSize: Int = 1024
let bgComponents: [CGFloat] = [10/255, 10/255, 10/255, 1.0]
let accentComponents: [CGFloat] = [204/255, 255/255, 102/255, 1.0]

let colorSpace = CGColorSpaceCreateDeviceRGB()
let bgColor = CGColor(colorSpace: colorSpace, components: bgComponents)!
let accentColor = CGColor(colorSpace: colorSpace, components: accentComponents)!

// Opaque (no alpha) bitmap context — App Store rejects icons with alpha.
guard let ctx = CGContext(
    data: nil,
    width: canvasSize,
    height: canvasSize,
    bitsPerComponent: 8,
    bytesPerRow: 0,
    space: colorSpace,
    bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
) else {
    fputs("Failed to create CGContext\n", stderr)
    exit(1)
}

let canvas = CGFloat(canvasSize)

// 1. Black background
ctx.setFillColor(bgColor)
ctx.fill(CGRect(x: 0, y: 0, width: canvas, height: canvas))

// 2. Lime square "loop" border
let borderSize: CGFloat = 760
let borderInset = (canvas - borderSize) / 2
let borderLineWidth: CGFloat = 56
ctx.setStrokeColor(accentColor)
ctx.setLineWidth(borderLineWidth)
ctx.stroke(CGRect(x: borderInset, y: borderInset, width: borderSize, height: borderSize))

// 3. VT323 "$" glyph, centered
// Bridge into Core Text to draw with exact font + color.
let glyph = "$" as CFString
let attrs: [CFString: Any] = [
    kCTFontAttributeName: CTFontCreateWithName("VT323-Regular" as CFString, 720, nil),
    kCTForegroundColorAttributeName: accentColor,
]
let attrString = CFAttributedStringCreate(nil, glyph, attrs as CFDictionary)!
let line = CTLineCreateWithAttributedString(attrString)
let glyphBounds = CTLineGetImageBounds(line, ctx)

// Center the glyph rect within canvas, then nudge down a touch for optical balance.
let glyphX = (canvas - glyphBounds.width) / 2 - glyphBounds.origin.x
let glyphY = (canvas - glyphBounds.height) / 2 - glyphBounds.origin.y - 28
ctx.textPosition = CGPoint(x: glyphX, y: glyphY)
CTLineDraw(line, ctx)

// MARK: - Encode & write

guard let image = ctx.makeImage() else {
    fputs("Failed to create CGImage from context\n", stderr)
    exit(1)
}
guard let dest = CGImageDestinationCreateWithURL(outputURL as CFURL, UTType.png.identifier as CFString, 1, nil) else {
    fputs("Failed to create PNG destination\n", stderr)
    exit(1)
}
CGImageDestinationAddImage(dest, image, nil)
guard CGImageDestinationFinalize(dest) else {
    fputs("Failed to finalize PNG\n", stderr)
    exit(1)
}

print("Wrote \(image.width)×\(image.height) opaque PNG → \(outputURL.path)")
