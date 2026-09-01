import AppKit
import CoreGraphics
import Foundation

struct IconOutput {
    let filename: String
    let size: Int
}

let outputDirectory = CommandLine.arguments.dropFirst().first ?? "app/DayTraceSpike/DayTraceSpike/Assets.xcassets/AppIcon.appiconset"
let outputs = [
    IconOutput(filename: "icon-16.png", size: 16),
    IconOutput(filename: "icon-32.png", size: 32),
    IconOutput(filename: "icon-64.png", size: 64),
    IconOutput(filename: "icon-128.png", size: 128),
    IconOutput(filename: "icon-256.png", size: 256),
    IconOutput(filename: "icon-512.png", size: 512),
    IconOutput(filename: "icon-1024.png", size: 1024)
]

private let background = CGColor(red: 24.0 / 255.0, green: 36.0 / 255.0, blue: 49.0 / 255.0, alpha: 1)
private let arc = CGColor(red: 216.0 / 255.0, green: 230.0 / 255.0, blue: 239.0 / 255.0, alpha: 1)
private let edge = CGColor(red: 185.0 / 255.0, green: 205.0 / 255.0, blue: 217.0 / 255.0, alpha: 0.72)
private let marker = CGColor(red: 229.0 / 255.0, green: 187.0 / 255.0, blue: 114.0 / 255.0, alpha: 1)

private func tracePath() -> CGPath {
    let path = CGMutablePath()
    path.move(to: CGPoint(x: 250, y: 676))
    path.addCurve(
        to: CGPoint(x: 596, y: 226),
        control1: CGPoint(x: 232, y: 590),
        control2: CGPoint(x: 242, y: 478)
    )
    path.addCurve(
        to: CGPoint(x: 832, y: 486),
        control1: CGPoint(x: 662, y: 236),
        control2: CGPoint(x: 832, y: 342)
    )
    path.addCurve(
        to: CGPoint(x: 548, y: 802),
        control1: CGPoint(x: 832, y: 650),
        control2: CGPoint(x: 706, y: 782)
    )
    return path
}

func drawIcon(size: Int) -> CGImage? {
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    guard let context = CGContext(
        data: nil,
        width: size,
        height: size,
        bitsPerComponent: 8,
        bytesPerRow: size * 4,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else { return nil }

    let scale = CGFloat(size) / 1024
    context.scaleBy(x: scale, y: scale)

    let backgroundPath = CGPath(
        roundedRect: CGRect(x: 24, y: 24, width: 976, height: 976),
        cornerWidth: 220,
        cornerHeight: 220,
        transform: nil
    )
    context.addPath(backgroundPath)
    context.clip()
    context.setFillColor(background)
    context.fill(CGRect(x: 0, y: 0, width: 1024, height: 1024))

    let trace = tracePath()
    context.addPath(trace)
    context.setStrokeColor(arc)
    context.setLineWidth(84)
    context.setLineCap(.round)
    context.strokePath()

    context.addPath(trace)
    context.setStrokeColor(edge)
    context.setLineWidth(18)
    context.strokePath()

    context.setFillColor(marker)
    context.fillEllipse(in: CGRect(x: 220, y: 646, width: 60, height: 60))

    return context.makeImage()
}

for output in outputs {
    guard let cgImage = drawIcon(size: output.size),
          let representation = NSBitmapImageRep(cgImage: cgImage).representation(using: .png, properties: [:]) else {
        fputs("Unable to render \(output.filename)\n", stderr)
        exit(1)
    }
    let url = URL(fileURLWithPath: outputDirectory).appendingPathComponent(output.filename)
    try representation.write(to: url)
}
