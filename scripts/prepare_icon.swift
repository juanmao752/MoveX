#!/usr/bin/env swift
import AppKit
import Foundation

guard CommandLine.arguments.count == 4 else {
    fputs("Usage: swift prepare_icon.swift <input-image> <output-icns> <output-preview-png>\n", stderr)
    exit(1)
}

let inputPath = CommandLine.arguments[1]
let outputIcnsPath = CommandLine.arguments[2]
let outputPreviewPath = CommandLine.arguments[3]

guard let sourceImage = NSImage(contentsOfFile: inputPath),
      let sourceCG = sourceImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
    fputs("Failed to load image at \(inputPath)\n", stderr)
    exit(1)
}

func renderSquircleIcon(source: CGImage, pixelSize: Int) -> Data? {
    let px = CGFloat(pixelSize)
    guard let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: pixelSize,
        pixelsHigh: pixelSize,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else {
        return nil
    }
    rep.size = NSSize(width: pixelSize, height: pixelSize)

    guard let ctx = NSGraphicsContext(bitmapImageRep: rep) else {
        return nil
    }

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = ctx
    defer { NSGraphicsContext.restoreGraphicsState() }

    ctx.cgContext.interpolationQuality = .high
    NSColor.clear.setFill()
    NSRect(x: 0, y: 0, width: px, height: px).fill()

    let inset = px * (100.0 / 1024.0)
    let bodyRect = NSRect(x: inset, y: inset, width: px - inset * 2.0, height: px - inset * 2.0)
    let radius = bodyRect.width * 0.225
    let squirclePath = NSBezierPath(roundedRect: bodyRect, xRadius: radius, yRadius: radius)

    if pixelSize >= 64 {
        ctx.saveGraphicsState()
        let shadow = NSShadow()
        shadow.shadowOffset = NSSize(width: 0, height: -px * 0.012)
        shadow.shadowBlurRadius = px * 0.028
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.32)
        shadow.set()
        NSColor.black.setFill()
        squirclePath.fill()
        ctx.restoreGraphicsState()
    }

    ctx.saveGraphicsState()
    squirclePath.addClip()

    let srcW = CGFloat(source.width)
    let srcH = CGFloat(source.height)
    let side = min(srcW, srcH)
    let cropRect = CGRect(
        x: (srcW - side) / 2.0,
        y: (srcH - side) / 2.0,
        width: side,
        height: side
    )

    if let cropped = source.cropping(to: cropRect) {
        ctx.cgContext.draw(cropped, in: bodyRect)
    } else {
        ctx.cgContext.draw(source, in: bodyRect)
    }
    ctx.restoreGraphicsState()

    return rep.representation(using: .png, properties: [:])
}

let tempDir = FileManager.default.temporaryDirectory
    .appendingPathComponent("commandx-iconset-\(UUID().uuidString)")
    .appendingPathExtension("iconset")

try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
defer { try? FileManager.default.removeItem(at: tempDir) }

let sizes: [(px: Int, name: String)] = [
    (16, "icon_16x16.png"),
    (32, "icon_16x16@2x.png"),
    (32, "icon_32x32.png"),
    (64, "icon_32x32@2x.png"),
    (128, "icon_128x128.png"),
    (256, "icon_128x128@2x.png"),
    (256, "icon_256x256.png"),
    (512, "icon_256x256@2x.png"),
    (512, "icon_512x512.png"),
    (1024, "icon_512x512@2x.png")
]

var renderedCache: [Int: Data] = [:]
for entry in sizes {
    let data: Data
    if let cached = renderedCache[entry.px] {
        data = cached
    } else if let generated = renderSquircleIcon(source: sourceCG, pixelSize: entry.px) {
        renderedCache[entry.px] = generated
        data = generated
    } else {
        fputs("Failed to render \(entry.px)px icon\n", stderr)
        exit(1)
    }
    let outFile = tempDir.appendingPathComponent(entry.name)
    try data.write(to: outFile)
}

if let previewData = renderedCache[1024] {
    let previewURL = URL(fileURLWithPath: outputPreviewPath)
    try FileManager.default.createDirectory(at: previewURL.deletingLastPathComponent(), withIntermediateDirectories: true)
    try previewData.write(to: previewURL)
}

let icnsURL = URL(fileURLWithPath: outputIcnsPath)
try FileManager.default.createDirectory(at: icnsURL.deletingLastPathComponent(), withIntermediateDirectories: true)

let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
process.arguments = ["-c", "icns", tempDir.path, "-o", icnsURL.path]
try process.run()
process.waitUntilExit()

if process.terminationStatus != 0 {
    fputs("iconutil failed with status \(process.terminationStatus)\n", stderr)
    exit(process.terminationStatus)
}

print("Generated \(icnsURL.path) and \(outputPreviewPath)")
