#!/usr/bin/env swift
//
// generate_app_icon.swift
//
// Source-of-truth renderer for the 1024×1024 App Store icon. Outputs an
// opaque PNG straight into the AppIcon.appiconset.
//
// Run from the repo root:
//   swift scripts/generate_app_icon.swift
//
// Design: pixel-art "PennyLoop mascot" — a smiling coin face with a small
// `$` mark on the forehead. Lime on pure black, no peripheral structures so
// Apple's squircle mask can't clip anything important.

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
let colorSpace = CGColorSpaceCreateDeviceRGB()
let bg     = CGColor(colorSpace: colorSpace, components: [CGFloat(10)/255,  CGFloat(10)/255,  CGFloat(10)/255, 1.0])!
let accent = CGColor(colorSpace: colorSpace, components: [CGFloat(204)/255, CGFloat(255)/255, CGFloat(102)/255, 1.0])!

// Opaque bitmap context — App Store rejects alpha.
guard let ctx = CGContext(
    data: nil,
    width: canvasSize, height: canvasSize,
    bitsPerComponent: 8, bytesPerRow: 0,
    space: colorSpace,
    bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
) else { fputs("CGContext init failed\n", stderr); exit(1) }

let canvas = CGFloat(canvasSize)

// 1. Background.
ctx.setFillColor(bg)
ctx.fill(CGRect(x: 0, y: 0, width: canvas, height: canvas))

// 2. Pixel-art coin face — filled disc approximated with chunky squares.
let center = CGPoint(x: canvas / 2, y: canvas / 2 - 20)
let faceRadius: CGFloat = 380
let pixel: CGFloat = 32

func fillPixelDisc(centerPt c: CGPoint, radius r: CGFloat, pixelSize p: CGFloat) {
    let steps = Int((r * 2) / p) + 2
    let originX = c.x - r
    let originY = c.y - r
    for row in 0..<steps {
        for col in 0..<steps {
            let cx = originX + (CGFloat(col) + 0.5) * p
            let cy = originY + (CGFloat(row) + 0.5) * p
            let dx = cx - c.x
            let dy = cy - c.y
            if dx*dx + dy*dy <= r*r {
                ctx.fill(CGRect(x: originX + CGFloat(col) * p,
                                y: originY + CGFloat(row) * p,
                                width: p, height: p))
            }
        }
    }
}

ctx.setFillColor(accent)
fillPixelDisc(centerPt: center, radius: faceRadius, pixelSize: pixel)

// 3. Eyes — two chunky black squares, sized to read at 60pt home-screen.
ctx.setFillColor(bg)
let eyeSize: CGFloat = 90
let eyeY = center.y + 60
ctx.fill(CGRect(x: center.x - 170, y: eyeY, width: eyeSize, height: eyeSize))
ctx.fill(CGRect(x: center.x + 80,  y: eyeY, width: eyeSize, height: eyeSize))

// 4. Smile — a single black "cleft" shape, two stacked rectangles that read
// as a confident, satisfied grin.
let mouthTopY: CGFloat = center.y - 100
let mouthTopW: CGFloat = 380
let mouthBottomW: CGFloat = 260
let mouthHeight: CGFloat = 40
ctx.fill(CGRect(x: center.x - mouthTopW/2,    y: mouthTopY + mouthHeight, width: mouthTopW,    height: mouthHeight))
ctx.fill(CGRect(x: center.x - mouthBottomW/2, y: mouthTopY,                width: mouthBottomW, height: mouthHeight))

// 5. Forehead "$" — small VT323 dollar mark, sized so it doesn't compete
// with the face. Renders in black against the lime face.
let dollarFont = CTFontCreateWithName("VT323-Regular" as CFString, 180, nil)
let attrs: [CFString: Any] = [
    kCTFontAttributeName: dollarFont,
    kCTForegroundColorAttributeName: bg,
]
let dollar = CFAttributedStringCreate(nil, "$" as CFString, attrs as CFDictionary)!
let line = CTLineCreateWithAttributedString(dollar)
let bounds = CTLineGetImageBounds(line, ctx)
ctx.textPosition = CGPoint(
    x: center.x - bounds.width/2 - bounds.origin.x,
    y: center.y + 230 - bounds.height/2 - bounds.origin.y
)
CTLineDraw(line, ctx)

// MARK: - Encode + write

guard let image = ctx.makeImage() else { fputs("makeImage failed\n", stderr); exit(1) }
guard let dest = CGImageDestinationCreateWithURL(outputURL as CFURL, UTType.png.identifier as CFString, 1, nil)
else { fputs("PNG dest failed\n", stderr); exit(1) }
CGImageDestinationAddImage(dest, image, nil)
guard CGImageDestinationFinalize(dest) else { fputs("PNG finalize failed\n", stderr); exit(1) }

print("Wrote \(image.width)×\(image.height) opaque PNG → \(outputURL.path)")
