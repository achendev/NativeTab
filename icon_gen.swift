import Cocoa

let size: CGFloat = 1024
let padding: CGFloat = 120 // Proper padding for macOS dock icons
let cornerRadius: CGFloat = 225 // Standard macOS squircle radius for 1024x1024
let canvasRect = NSRect(x: 0, y: 0, width: size, height: size)
let iconRect = canvasRect.insetBy(dx: padding, dy: padding)

// 1. Create Image Context
let img = NSImage(size: NSSize(width: size, height: size))
img.lockFocus()

// 2. Clear Background (Transparency)
NSColor.clear.set()
NSBezierPath(rect: canvasRect).fill()

// 3. Load and Draw the Source Image with a Mask
let sourcePath = "NativeTab.png"
if let sourceImage = NSImage(contentsOfFile: sourcePath) {
    let path = NSBezierPath(roundedRect: iconRect, xRadius: cornerRadius, yRadius: cornerRadius)
    path.addClip()
    
    sourceImage.draw(in: iconRect, from: NSRect(origin: .zero, size: sourceImage.size), operation: .sourceOver, fraction: 1.0)
} else {
    print("Error: Could not load \(sourcePath)")
}

img.unlockFocus()

// 4. Save as PNG
if let tiff = img.tiffRepresentation,
   let bitmap = NSBitmapImageRep(data: tiff),
   let pngData = bitmap.representation(using: .png, properties: [:]) {
    try? pngData.write(to: URL(fileURLWithPath: "icon_1024.png"))
}
