#!/usr/bin/env swift
//
// icon_variants.swift
//
// Generates 6 candidate 1024×1024 App Store icons to /tmp for review.
// Pick a favorite, then port the winning code into generate_app_icon.swift
// and run to commit it into the AppIcon.appiconset.
//
//   swift scripts/icon_variants.swift
//
// All candidates share the same brand palette (black bg, lime accent) and
// stay clear of the canvas corners so Apple's squircle mask can't clip
// peripheral structures.

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
let bg = CGColor(colorSpace: colorSpace, components: [CGFloat(10)/255, CGFloat(10)/255, CGFloat(10)/255, 1.0])!
let accent = CGColor(colorSpace: colorSpace, components: [CGFloat(204)/255, CGFloat(255)/255, CGFloat(102)/255, 1.0])!

// MARK: - Helpers

func newContext() -> CGContext {
    let ctx = CGContext(
        data: nil,
        width: canvasSize, height: canvasSize,
        bitsPerComponent: 8, bytesPerRow: 0,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
    )!
    ctx.setFillColor(bg)
    ctx.fill(CGRect(x: 0, y: 0, width: canvasSize, height: canvasSize))
    return ctx
}

func writePNG(_ ctx: CGContext, to outURL: URL) {
    guard let image = ctx.makeImage(),
          let dest = CGImageDestinationCreateWithURL(outURL as CFURL, UTType.png.identifier as CFString, 1, nil)
    else { fputs("encode/write failed for \(outURL.path)\n", stderr); exit(1) }
    CGImageDestinationAddImage(dest, image, nil)
    CGImageDestinationFinalize(dest)
    print("Wrote \(outURL.lastPathComponent) (\(image.width)×\(image.height))")
}

func drawString(_ text: String, font: CTFont, in ctx: CGContext, center: CGPoint, yOffset: CGFloat = 0, color: CGColor? = nil) {
    let attrs: [CFString: Any] = [
        kCTFontAttributeName: font,
        kCTForegroundColorAttributeName: color ?? accent,
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

// MARK: - V1: PL monogram

func renderV1_PL() -> CGContext {
    let ctx = newContext()
    let canvas = CGFloat(canvasSize)
    let font = CTFontCreateWithName("VT323-Regular" as CFString, 780, nil)
    drawString("PL", font: font, in: ctx, center: CGPoint(x: canvas/2, y: canvas/2), yOffset: -20)
    ctx.setFillColor(accent)
    ctx.fill(CGRect(x: canvas/2 - 60, y: 130, width: 120, height: 18))
    return ctx
}

// MARK: - V2: Stacked subscription cards

func renderV2_Cards() -> CGContext {
    let ctx = newContext()
    let canvas = CGFloat(canvasSize)
    let cardWidth: CGFloat = 660
    let cardHeight: CGFloat = 130
    let gap: CGFloat = 40
    let totalHeight = cardHeight * 3 + gap * 2
    let firstY = (canvas - totalHeight) / 2

    for i in 0..<3 {
        let y = firstY + CGFloat(i) * (cardHeight + gap)
        let cardRect = CGRect(x: (canvas - cardWidth) / 2, y: y, width: cardWidth, height: cardHeight)
        ctx.setStrokeColor(accent)
        ctx.setLineWidth(14)
        ctx.stroke(cardRect)

        // Top-most card (visually, lowest y in CG) is the "next renewal" — solid fill.
        if i == 2 {
            ctx.setFillColor(accent)
            ctx.fill(cardRect.insetBy(dx: 7, dy: 7))
        }

        // Row "icon" indicator on the left of each card.
        let dotSize: CGFloat = 50
        let dot = CGRect(x: cardRect.minX + 40, y: cardRect.midY - dotSize/2, width: dotSize, height: dotSize)
        ctx.setFillColor(i == 2 ? bg : accent)
        ctx.fill(dot)
    }
    return ctx
}

// MARK: - V3: Coin in pixel loop (cleaner arrowhead)

func renderV3_Loop() -> CGContext {
    let ctx = newContext()
    let canvas = CGFloat(canvasSize)
    let center = CGPoint(x: canvas/2, y: canvas/2)

    let ringRadius: CGFloat = 340
    let pixel: CGFloat = 36
    let steps = 56
    ctx.setFillColor(accent)

    // Draw a pixel-dotted ring, but skip a wedge at the top-right for the arrowhead.
    let gapStart = Double.pi * 0.05
    let gapEnd = Double.pi * 0.25
    for i in 0..<steps {
        let theta = (Double(i) / Double(steps)) * 2 * Double.pi
        if theta >= gapStart && theta <= gapEnd { continue }
        let x = center.x + CGFloat(cos(theta)) * ringRadius - pixel/2
        let y = center.y + CGFloat(sin(theta)) * ringRadius - pixel/2
        ctx.fill(CGRect(x: x, y: y, width: pixel, height: pixel))
    }

    // Pixel arrowhead — three stacked rectangles at the wedge gap pointing
    // clockwise (so the loop reads as a renewal cycle).
    let tipTheta = (gapStart + gapEnd) / 2
    let tipX = center.x + CGFloat(cos(tipTheta)) * ringRadius
    let tipY = center.y + CGFloat(sin(tipTheta)) * ringRadius
    let arrowBlocks: [(dx: CGFloat, dy: CGFloat, size: CGFloat)] = [
        (0,     0,    78),
        (-50,   30,   58),
        (40,   -40,   58),
    ]
    for b in arrowBlocks {
        ctx.fill(CGRect(x: tipX + b.dx - b.size/2, y: tipY + b.dy - b.size/2, width: b.size, height: b.size))
    }

    // "$" inside the loop
    let font = CTFontCreateWithName("VT323-Regular" as CFString, 480, nil)
    drawString("$", font: font, in: ctx, center: center, yOffset: -14)
    return ctx
}

// MARK: - V4: Pixel calendar with highlighted "next renewal" cell

func renderV4_Calendar() -> CGContext {
    let ctx = newContext()
    let canvas = CGFloat(canvasSize)
    let cellSize: CGFloat = 110
    let gap: CGFloat = 20
    let cols = 4, rows = 4
    let gridWidth = CGFloat(cols) * cellSize + CGFloat(cols - 1) * gap
    let gridHeight = CGFloat(rows) * cellSize + CGFloat(rows - 1) * gap
    let originX = (canvas - gridWidth) / 2
    let originY = (canvas - gridHeight) / 2 - 40 // bias up to leave room for binder rings

    // Binder rings at the top of the "calendar".
    ctx.setFillColor(accent)
    let ringSize: CGFloat = 60
    let ringSpacing: CGFloat = gridWidth / 3
    let ringY = originY + gridHeight + 60
    for i in 0..<2 {
        let x = originX + (gridWidth - ringSpacing) * 0.5 + (CGFloat(i) * ringSpacing) - ringSize/2
        ctx.fill(CGRect(x: x, y: ringY, width: ringSize, height: ringSize))
    }

    // Cells: outline all, fill one specific cell as the "next renewal".
    let highlightedRow = 1
    let highlightedCol = 2
    ctx.setStrokeColor(accent)
    ctx.setLineWidth(8)
    for r in 0..<rows {
        for c in 0..<cols {
            let x = originX + CGFloat(c) * (cellSize + gap)
            let y = originY + CGFloat(rows - 1 - r) * (cellSize + gap)
            let rect = CGRect(x: x, y: y, width: cellSize, height: cellSize)
            if r == highlightedRow && c == highlightedCol {
                ctx.setFillColor(accent)
                ctx.fill(rect)
            } else {
                ctx.stroke(rect)
            }
        }
    }
    return ctx
}

// MARK: - V5: Big bold "$" — minimalist, no frame

func renderV5_BigDollar() -> CGContext {
    let ctx = newContext()
    let canvas = CGFloat(canvasSize)
    let font = CTFontCreateWithName("VT323-Regular" as CFString, 1000, nil)
    drawString("$", font: font, in: ctx, center: CGPoint(x: canvas/2, y: canvas/2), yOffset: -40)
    return ctx
}

// MARK: - V6: Pixel bell with renewal dot

func renderV6_Bell() -> CGContext {
    let ctx = newContext()
    let canvas = CGFloat(canvasSize)
    let centerX = canvas / 2
    let bellTopY: CGFloat = 800
    let pixel: CGFloat = 60
    ctx.setFillColor(accent)

    // Pixel bell shape — built from rows of rectangles. (0,0) is bottom-left in CG.
    // We define the bell upside-down then flip y when filling.
    // Row pattern: width (in pixels) per row, top to bottom.
    let widths: [Int] = [3, 5, 7, 9, 9, 9, 11, 11, 11]
    var y = bellTopY
    for w in widths {
        let totalWidth = CGFloat(w) * pixel
        let startX = centerX - totalWidth / 2
        for i in 0..<w {
            ctx.fill(CGRect(x: startX + CGFloat(i) * pixel, y: y, width: pixel, height: pixel))
        }
        y -= pixel
    }
    // Clapper — a small block under the bell.
    let clapperW: CGFloat = pixel * 3
    let clapperH: CGFloat = pixel
    ctx.fill(CGRect(x: centerX - clapperW/2, y: y - 8, width: clapperW, height: clapperH))

    // Renewal dot — a lime square in the upper-right corner of the bell area
    // suggests an unread notification badge.
    let badgeSize: CGFloat = pixel * 2.2
    ctx.fill(CGRect(x: centerX + 240, y: bellTopY + 40, width: badgeSize, height: badgeSize))

    return ctx
}

// MARK: - Render

let outDir = URL(fileURLWithPath: "/tmp")
writePNG(renderV1_PL(),       to: outDir.appendingPathComponent("icon_v1_pl.png"))
writePNG(renderV2_Cards(),    to: outDir.appendingPathComponent("icon_v2_cards.png"))
writePNG(renderV3_Loop(),     to: outDir.appendingPathComponent("icon_v3_loop.png"))
writePNG(renderV4_Calendar(), to: outDir.appendingPathComponent("icon_v4_calendar.png"))
writePNG(renderV5_BigDollar(), to: outDir.appendingPathComponent("icon_v5_dollar.png"))
writePNG(renderV6_Bell(),     to: outDir.appendingPathComponent("icon_v6_bell.png"))
