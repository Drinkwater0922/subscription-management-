#!/usr/bin/env swift
//
// icon_variants3.swift
//
// Round 3 — distinctive brand marks. Forget generic $/coin/calendar; each
// candidate is a custom-drawn pixel symbol that's specific to PennyLoop.
//
//   swift scripts/icon_variants3.swift
//
// Writes:
//   /tmp/icon_v12_loop_dollar.png — $ whose bottom flick curls into a loop arrow
//   /tmp/icon_v13_trail.png       — $ with two ghost copies behind it (recurrence)
//   /tmp/icon_v14_ligature.png    — Custom "PL" ligature lockup (one continuous mark)
//   /tmp/icon_v15_serpent.png     — Trail of small $ glyphs winding through the canvas
//
// Palette stays black + lime. White is a thin highlight in v13.

import AppKit
import CoreText
import ImageIO
import UniformTypeIdentifiers

// MARK: - Setup

let scriptURL = URL(fileURLWithPath: #filePath).resolvingSymlinksInPath()
let repoRoot = scriptURL.deletingLastPathComponent().deletingLastPathComponent()
let fontURL = repoRoot.appendingPathComponent("Trackr/DesignSystem/Resources/VT323-Regular.ttf")

var fontError: Unmanaged<CFError>?
guard CTFontManagerRegisterFontsForURL(fontURL as CFURL, .process, &fontError) else {
    fputs("Failed to register VT323: \(fontError?.takeRetainedValue().localizedDescription ?? "?")\n", stderr)
    exit(1)
}

let canvasSize: Int = 1024
let colorSpace = CGColorSpaceCreateDeviceRGB()
let bg     = CGColor(colorSpace: colorSpace, components: [CGFloat(10)/255,  CGFloat(10)/255,  CGFloat(10)/255, 1.0])!
let accent = CGColor(colorSpace: colorSpace, components: [CGFloat(204)/255, CGFloat(255)/255, CGFloat(102)/255, 1.0])!
let dim    = CGColor(colorSpace: colorSpace, components: [CGFloat(105)/255, CGFloat(140)/255, CGFloat(50)/255,  1.0])! // 50%-lime "ghost" tone

// MARK: - Helpers

func newContext() -> CGContext {
    let ctx = CGContext(
        data: nil, width: canvasSize, height: canvasSize,
        bitsPerComponent: 8, bytesPerRow: 0, space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
    )!
    ctx.setFillColor(bg)
    ctx.fill(CGRect(x: 0, y: 0, width: canvasSize, height: canvasSize))
    return ctx
}

func writePNG(_ ctx: CGContext, to outURL: URL) {
    guard let image = ctx.makeImage(),
          let dest = CGImageDestinationCreateWithURL(outURL as CFURL, UTType.png.identifier as CFString, 1, nil)
    else { fputs("write failed\n", stderr); exit(1) }
    CGImageDestinationAddImage(dest, image, nil)
    CGImageDestinationFinalize(dest)
    print("Wrote \(outURL.lastPathComponent)")
}

func drawString(_ text: String, font: CTFont, in ctx: CGContext, center: CGPoint, yOffset: CGFloat = 0, color: CGColor) {
    let attrs: [CFString: Any] = [
        kCTFontAttributeName: font,
        kCTForegroundColorAttributeName: color,
    ]
    let attr = CFAttributedStringCreate(nil, text as CFString, attrs as CFDictionary)!
    let line = CTLineCreateWithAttributedString(attr)
    let bounds = CTLineGetImageBounds(line, ctx)
    ctx.textPosition = CGPoint(
        x: center.x - bounds.width/2 - bounds.origin.x,
        y: center.y - bounds.height/2 - bounds.origin.y + yOffset
    )
    CTLineDraw(line, ctx)
}

/// Fills cells of a grid where `pattern` is a 2D string array (one row per
/// line). "#" = lime, "." = bg. Helpers for hand-drawn pixel glyphs.
func paintPattern(_ pattern: [String], at origin: CGPoint, cell: CGFloat, in ctx: CGContext, color: CGColor) {
    ctx.setFillColor(color)
    let rows = pattern.count
    for (r, line) in pattern.enumerated() {
        for (c, ch) in line.enumerated() where ch == "#" {
            // (0,0) at top-left of pattern; CG y is bottom-up so flip row.
            let x = origin.x + CGFloat(c) * cell
            let y = origin.y + CGFloat(rows - 1 - r) * cell
            ctx.fill(CGRect(x: x, y: y, width: cell, height: cell))
        }
    }
}

// MARK: - V12: Loop-dollar — $ whose bottom flick becomes a back-curled arrow

func renderV12_LoopDollar() -> CGContext {
    let ctx = newContext()
    let cell: CGFloat = 36

    // Hand-drawn 22-wide × 22-tall glyph. The right column's lower half
    // bulges out as an arrowhead curling clockwise back toward the stem.
    let pattern = [
        "..........####........",
        "........########......",
        "......####....####....",
        "....####........####..",
        "....####........####..",
        "..######........######",
        "..######........######",
        "..######..........####",
        "....######............",
        "......######..........",
        "........######........",
        "..........######......",
        "............######....",
        "..............######..",
        "................######",
        "................######",
        "..####............####",
        "..####..........######",
        "..####........######..",
        "..######..######......",
        "....##########........",
        "......######..........",
    ]
    let glyphWidth = CGFloat(22) * cell
    let glyphHeight = CGFloat(22) * cell
    let canvas = CGFloat(canvasSize)
    let origin = CGPoint(x: (canvas - glyphWidth) / 2,
                         y: (canvas - glyphHeight) / 2)
    paintPattern(pattern, at: origin, cell: cell, in: ctx, color: accent)
    return ctx
}

// MARK: - V13: $ with motion trail

func renderV13_Trail() -> CGContext {
    let ctx = newContext()
    let canvas = CGFloat(canvasSize)
    let center = CGPoint(x: canvas/2, y: canvas/2)
    let font = CTFontCreateWithName("VT323-Regular" as CFString, 760, nil)

    // Far ghost
    drawString("$", font: font, in: ctx, center: CGPoint(x: center.x - 200, y: center.y - 70), yOffset: -20, color: dim)
    // Mid ghost — render the same dim color but slightly larger overlap.
    drawString("$", font: font, in: ctx, center: CGPoint(x: center.x - 90, y: center.y - 30), yOffset: -20, color: dim)
    // Foreground $ in full lime
    drawString("$", font: font, in: ctx, center: center, yOffset: -20, color: accent)
    return ctx
}

// MARK: - V14: Custom "PL" ligature — one continuous mark

func renderV14_Ligature() -> CGContext {
    let ctx = newContext()
    let cell: CGFloat = 40

    // 18-wide × 22-tall hand-drawn ligature. The P's right wall slides down
    // and right into the L's foot — they share the vertical stem.
    let pattern = [
        "##############....",
        "##############....",
        "####......####....",
        "####......####....",
        "####......####....",
        "####......####....",
        "##############....",
        "##############....",
        "####..............",
        "####..............",
        "####..............",
        "####..............",
        "####..............",
        "####..............",
        "####..............",
        "####..............",
        "####..............",
        "####..............",
        "####..............",
        "####..............",
        "##################",
        "##################",
    ]
    let glyphWidth = CGFloat(18) * cell
    let glyphHeight = CGFloat(22) * cell
    let canvas = CGFloat(canvasSize)
    let origin = CGPoint(x: (canvas - glyphWidth) / 2,
                         y: (canvas - glyphHeight) / 2)
    paintPattern(pattern, at: origin, cell: cell, in: ctx, color: accent)
    return ctx
}

// MARK: - V15: Serpent of small dollar signs (recurrence as a winding trail)

func renderV15_Serpent() -> CGContext {
    let ctx = newContext()
    let canvas = CGFloat(canvasSize)
    let font = CTFontCreateWithName("VT323-Regular" as CFString, 200, nil)

    // 5 dollar glyphs in a winding S-curve, alternating between two row
    // heights, getting slightly larger from left to right (motion / growth).
    let points: [(x: CGFloat, y: CGFloat, scale: CGFloat)] = [
        (canvas * 0.20, canvas * 0.30, 0.6),
        (canvas * 0.40, canvas * 0.50, 0.8),
        (canvas * 0.55, canvas * 0.35, 1.0),
        (canvas * 0.70, canvas * 0.55, 1.2),
        (canvas * 0.82, canvas * 0.70, 1.5),
    ]
    for (i, p) in points.enumerated() {
        let f = CTFontCreateWithName("VT323-Regular" as CFString, 200 * p.scale, nil)
        let color: CGColor = i == points.count - 1 ? accent : dim
        drawString("$", font: f, in: ctx, center: CGPoint(x: p.x, y: p.y), yOffset: 0, color: color)
    }
    return ctx
}

// MARK: - Render

let outDir = URL(fileURLWithPath: "/tmp")
writePNG(renderV12_LoopDollar(), to: outDir.appendingPathComponent("icon_v12_loop_dollar.png"))
writePNG(renderV13_Trail(),      to: outDir.appendingPathComponent("icon_v13_trail.png"))
writePNG(renderV14_Ligature(),   to: outDir.appendingPathComponent("icon_v14_ligature.png"))
writePNG(renderV15_Serpent(),    to: outDir.appendingPathComponent("icon_v15_serpent.png"))
