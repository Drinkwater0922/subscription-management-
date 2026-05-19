#!/usr/bin/env swift
//
// icon_variants2.swift
//
// Second round of icon candidates — leaning harder into the "Penny" half of
// PennyLoop (coin imagery) and into more illustrative pixel-art shapes that
// have a stronger silhouette than letterforms.
//
//   swift scripts/icon_variants2.swift
//
// Writes:
//   /tmp/icon_v7_coin.png       — Pixel coin face (serrated edge + $)
//   /tmp/icon_v8_infinity.png   — Two interlocking coins (infinity / loop)
//   /tmp/icon_v9_stack.png      — Isometric stack of pixel coins
//   /tmp/icon_v10_wallet.png    — Pixel wallet with coin peeking out
//   /tmp/icon_v11_mascot.png    — Smiling penny mascot (Duolingo-style appeal)

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
let darken = CGColor(colorSpace: colorSpace, components: [CGFloat(140)/255, CGFloat(180)/255, CGFloat(70)/255,  1.0])! // accent shadow
let white  = CGColor(colorSpace: colorSpace, components: [CGFloat(245)/255, CGFloat(245)/255, CGFloat(240)/255, 1.0])!

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
    else { fputs("encode failed for \(outURL.path)\n", stderr); exit(1) }
    CGImageDestinationAddImage(dest, image, nil)
    CGImageDestinationFinalize(dest)
    print("Wrote \(outURL.lastPathComponent)")
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

/// Approximates a filled disc using square pixels — gives the chunky 8-bit feel.
func fillPixelDisc(in ctx: CGContext, center: CGPoint, radius: CGFloat, pixel: CGFloat, color: CGColor) {
    ctx.setFillColor(color)
    let steps = Int((radius * 2) / pixel) + 2
    let originX = center.x - radius
    let originY = center.y - radius
    for r in 0..<steps {
        for c in 0..<steps {
            let cx = originX + (CGFloat(c) + 0.5) * pixel
            let cy = originY + (CGFloat(r) + 0.5) * pixel
            let dx = cx - center.x
            let dy = cy - center.y
            if dx*dx + dy*dy <= radius*radius {
                ctx.fill(CGRect(x: originX + CGFloat(c) * pixel,
                                y: originY + CGFloat(r) * pixel,
                                width: pixel, height: pixel))
            }
        }
    }
}

func strokePixelRing(in ctx: CGContext, center: CGPoint, radius: CGFloat, pixel: CGFloat, steps: Int, color: CGColor) {
    ctx.setFillColor(color)
    for i in 0..<steps {
        let theta = (Double(i) / Double(steps)) * 2 * Double.pi
        let x = center.x + CGFloat(cos(theta)) * radius - pixel/2
        let y = center.y + CGFloat(sin(theta)) * radius - pixel/2
        ctx.fill(CGRect(x: x, y: y, width: pixel, height: pixel))
    }
}

// MARK: - V7: Pixel coin face

func renderV7_Coin() -> CGContext {
    let ctx = newContext()
    let canvas = CGFloat(canvasSize)
    let center = CGPoint(x: canvas/2, y: canvas/2)

    // Solid filled coin body (pixel-disc).
    fillPixelDisc(in: ctx, center: center, radius: 350, pixel: 28, color: accent)

    // Inner darker ring inset — gives the coin a "rim" detail.
    strokePixelRing(in: ctx, center: center, radius: 290, pixel: 22, steps: 64, color: darken)

    // "$" struck onto the coin.
    let font = CTFontCreateWithName("VT323-Regular" as CFString, 460, nil)
    drawString("$", font: font, in: ctx, center: center, yOffset: -14, color: bg)

    return ctx
}

// MARK: - V8: Two interlocking coins (infinity / loop)

func renderV8_Infinity() -> CGContext {
    let ctx = newContext()
    let canvas = CGFloat(canvasSize)
    let r: CGFloat = 220
    let pixel: CGFloat = 22
    let centerLeft  = CGPoint(x: canvas/2 - r*0.85, y: canvas/2)
    let centerRight = CGPoint(x: canvas/2 + r*0.85, y: canvas/2)

    // Two solid pixel discs.
    fillPixelDisc(in: ctx, center: centerLeft,  radius: r, pixel: pixel, color: accent)
    fillPixelDisc(in: ctx, center: centerRight, radius: r, pixel: pixel, color: accent)

    // Overlap region: punch a small darker pixel cluster so the two coins read
    // as interlocking rather than fused.
    let overlapMid = CGPoint(x: canvas/2, y: canvas/2)
    fillPixelDisc(in: ctx, center: overlapMid, radius: 48, pixel: pixel, color: bg)

    // Dollar marks on each coin (small).
    let font = CTFontCreateWithName("VT323-Regular" as CFString, 240, nil)
    drawString("$", font: font, in: ctx, center: centerLeft,  yOffset: -8, color: bg)
    drawString("$", font: font, in: ctx, center: centerRight, yOffset: -8, color: bg)

    return ctx
}

// MARK: - V9: Isometric stack of pixel coins

func renderV9_Stack() -> CGContext {
    let ctx = newContext()
    let canvas = CGFloat(canvasSize)
    let cx = canvas / 2
    // Each coin is a flat ellipse drawn with pixel rectangles (top-down view
    // squashed vertically). Stack three with a small vertical offset.
    let pixel: CGFloat = 24
    let coinWidth: CGFloat = 580
    let coinHeight: CGFloat = 200
    let coinSpacing: CGFloat = 140

    let coins: [(y: CGFloat, color: CGColor)] = [
        (canvas/2 - coinSpacing,     darken),
        (canvas/2,                   accent),
        (canvas/2 + coinSpacing,     accent),
    ]

    func fillEllipsePixels(centerY: CGFloat, color: CGColor) {
        ctx.setFillColor(color)
        let rx = coinWidth / 2
        let ry = coinHeight / 2
        let cols = Int(coinWidth / pixel) + 2
        let rows = Int(coinHeight / pixel) + 2
        for r in 0..<rows {
            for c in 0..<cols {
                let pxCenterX = cx - rx + (CGFloat(c) + 0.5) * pixel
                let pxCenterY = centerY - ry + (CGFloat(r) + 0.5) * pixel
                let dx = (pxCenterX - cx) / rx
                let dy = (pxCenterY - centerY) / ry
                if dx*dx + dy*dy <= 1.0 {
                    ctx.fill(CGRect(x: cx - rx + CGFloat(c) * pixel,
                                    y: centerY - ry + CGFloat(r) * pixel,
                                    width: pixel, height: pixel))
                }
            }
        }
    }

    // Draw bottom coin first, so higher ones overlap it.
    for coin in coins {
        fillEllipsePixels(centerY: coin.y, color: coin.color)
    }

    // "$" on the topmost coin face.
    let font = CTFontCreateWithName("VT323-Regular" as CFString, 200, nil)
    drawString("$", font: font, in: ctx, center: CGPoint(x: cx, y: canvas/2 + coinSpacing), yOffset: -6, color: bg)

    return ctx
}

// MARK: - V10: Pixel wallet with coin peeking out

func renderV10_Wallet() -> CGContext {
    let ctx = newContext()
    let canvas = CGFloat(canvasSize)
    let walletWidth: CGFloat = 680
    let walletHeight: CGFloat = 460
    let walletX = (canvas - walletWidth) / 2
    let walletY = (canvas - walletHeight) / 2 - 30

    // Filled lime wallet body.
    ctx.setFillColor(accent)
    ctx.fill(CGRect(x: walletX, y: walletY, width: walletWidth, height: walletHeight))

    // Darker stripe across the upper edge — wallet seam.
    ctx.setFillColor(darken)
    ctx.fill(CGRect(x: walletX, y: walletY + walletHeight - 70, width: walletWidth, height: 28))

    // Snap button — small dark square on the right side of the seam.
    ctx.setFillColor(bg)
    ctx.fill(CGRect(x: walletX + walletWidth - 100, y: walletY + walletHeight - 80, width: 36, height: 50))

    // Coin peeking out from the top — half a pixel disc above the wallet.
    let coinCenter = CGPoint(x: walletX + walletWidth * 0.35, y: walletY + walletHeight + 30)
    fillPixelDisc(in: ctx, center: coinCenter, radius: 130, pixel: 22, color: accent)
    // Clip the bottom of the coin behind the wallet (paint a black bar over the lower half).
    ctx.setFillColor(bg)
    ctx.fill(CGRect(x: coinCenter.x - 150, y: walletY + walletHeight - 8, width: 300, height: 50))
    // Coin face "$".
    let font = CTFontCreateWithName("VT323-Regular" as CFString, 180, nil)
    drawString("$", font: font, in: ctx, center: CGPoint(x: coinCenter.x, y: coinCenter.y + 30), yOffset: 0, color: bg)

    return ctx
}

// MARK: - V11: Penny mascot (smiling coin)

func renderV11_Mascot() -> CGContext {
    let ctx = newContext()
    let canvas = CGFloat(canvasSize)
    let center = CGPoint(x: canvas/2, y: canvas/2 - 20)

    // Coin body.
    fillPixelDisc(in: ctx, center: center, radius: 360, pixel: 30, color: accent)

    // Eyes — two small dark squares.
    let eyeSize: CGFloat = 70
    ctx.setFillColor(bg)
    ctx.fill(CGRect(x: center.x - 150, y: center.y + 40, width: eyeSize, height: eyeSize))
    ctx.fill(CGRect(x: center.x + 80,  y: center.y + 40, width: eyeSize, height: eyeSize))

    // Smiling mouth — a chunky pixel arc made of three rectangles.
    let mouthY: CGFloat = center.y - 100
    let mouthBlocks: [(dx: CGFloat, dy: CGFloat, w: CGFloat, h: CGFloat)] = [
        (-110, 30,   60, 40),  // left tip up
        (-50,  0,   100, 40),  // middle dip
        (50,   0,   100, 40),  // middle dip
        (110,  30,   60, 40),  // right tip up
    ]
    for b in mouthBlocks {
        ctx.fill(CGRect(x: center.x + b.dx - b.w/2, y: mouthY + b.dy, width: b.w, height: b.h))
    }

    // Tiny "$" cheek/forehead marker — top center of the coin.
    let font = CTFontCreateWithName("VT323-Regular" as CFString, 140, nil)
    drawString("$", font: font, in: ctx, center: CGPoint(x: center.x, y: center.y + 230), yOffset: 0, color: bg)

    return ctx
}

// MARK: - Render

let outDir = URL(fileURLWithPath: "/tmp")
writePNG(renderV7_Coin(),    to: outDir.appendingPathComponent("icon_v7_coin.png"))
writePNG(renderV8_Infinity(), to: outDir.appendingPathComponent("icon_v8_infinity.png"))
writePNG(renderV9_Stack(),   to: outDir.appendingPathComponent("icon_v9_stack.png"))
writePNG(renderV10_Wallet(), to: outDir.appendingPathComponent("icon_v10_wallet.png"))
writePNG(renderV11_Mascot(), to: outDir.appendingPathComponent("icon_v11_mascot.png"))
