//
//  AppIconGenerator.swift
//  TrainState
//
//  Utility to generate app icons. Run in SwiftUI preview, tap "Save Icon" to export 1024x1024 PNG.
//

import SwiftUI
import UIKit

/// SwiftUI-based app icon generator matching the BBCards/todo app approach.
/// Preview this view, tap "Save Icon" to render and save to the asset catalog.
struct AppIconGenerator: View {
    var body: some View {
        VStack(spacing: 20) {
            Text("TrainState App Icon Generator")
                .font(.title)
                .fontWeight(.bold)

            // Icon design preview (scaled down for preview)
            AppIconDesign()
                .frame(width: 200, height: 200)
                .clipShape(RoundedRectangle(cornerRadius: 40))
                .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)

            Text("1024×1024 Icon")
                .font(.headline)

            Button("Save Icon") {
                saveIcon()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }

    private func saveIcon() {
        let design = AppIconDesign()
        let renderer = ImageRenderer(content: design)
        renderer.scale = 1.0

        guard let image = renderer.uiImage else {
            print("Failed to render icon")
            return
        }

        // Resize to exactly 1024×1024 if needed
        let finalImage: UIImage
        if image.size.width != 1024 || image.size.height != 1024 {
            let size = CGSize(width: 1024, height: 1024)
            let renderer = UIGraphicsImageRenderer(size: size)
            finalImage = renderer.image { _ in
                image.draw(in: CGRect(origin: .zero, size: size))
            }
        } else {
            finalImage = image
        }

        guard let pngData = finalImage.pngData() else {
            print("Failed to convert to PNG")
            return
        }

        // Save to Documents — drag into Xcode Assets.xcassets/AppIcon.appiconset
        guard let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            print("Could not access Documents")
            return
        }

        let outputURL = documentsURL.appendingPathComponent("TrainState-AppIcon-1024.png")
        do {
            try pngData.write(to: outputURL)
            print("Icon saved: \(outputURL.path)")
            print("Drag into TrainState/Assets.xcassets/AppIcon.appiconset as appstore.png")
        } catch {
            print("Save error: \(error)")
        }
    }
}

/// The actual icon design — gradient + dumbbell + TS monogram.
private struct AppIconDesign: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.blue, Color.purple],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            VStack(spacing: 12) {
                Image(systemName: "dumbbell.fill")
                    .font(.system(size: 120))
                    .foregroundColor(.white)

                Text("TS")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            }
        }
        .frame(width: 1024, height: 1024)
    }
}

#Preview {
    AppIconGenerator()
}
