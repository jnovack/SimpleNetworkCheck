import AppKit
import Foundation

let size: CGFloat = 1024
let image = NSImage(size: NSSize(width: size, height: size))

image.lockFocus()

let bounds = NSRect(x: 0, y: 0, width: size, height: size)
let bg = NSGradient(colors: [
    NSColor(calibratedRed: 0.06, green: 0.40, blue: 0.85, alpha: 1.0),
    NSColor(calibratedRed: 0.10, green: 0.72, blue: 0.95, alpha: 1.0)
])
bg?.draw(in: bounds, angle: 90)

let corner = NSBezierPath(roundedRect: bounds.insetBy(dx: 36, dy: 36), xRadius: 180, yRadius: 180)
NSColor(calibratedWhite: 1.0, alpha: 0.12).setFill()
corner.fill()

let center = NSPoint(x: size / 2, y: size * 0.42)
let lineColor = NSColor.white

func drawArc(radius: CGFloat, width: CGFloat) {
    let start = CGFloat(30)
    let end = CGFloat(150)
    let path = NSBezierPath()
    path.appendArc(withCenter: center, radius: radius, startAngle: start, endAngle: end)
    path.lineWidth = width
    path.lineCapStyle = .round
    lineColor.setStroke()
    path.stroke()
}

drawArc(radius: 340, width: 52)
drawArc(radius: 245, width: 52)
drawArc(radius: 150, width: 52)

let dot = NSBezierPath(ovalIn: NSRect(x: center.x - 46, y: center.y - 46, width: 92, height: 92))
lineColor.setFill()
dot.fill()

image.unlockFocus()

guard let tiff = image.tiffRepresentation,
      let rep = NSBitmapImageRep(data: tiff),
      let png = rep.representation(using: .png, properties: [:]) else {
    fatalError("Failed to generate icon PNG")
}

let output = URL(fileURLWithPath: "assets/AppIcon.png")
try png.write(to: output)
print("Wrote \(output.path)")
