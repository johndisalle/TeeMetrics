// MARK: - CourseHeroImage (Session C)
// Tiny SwiftUI wrapper around CourseImageService that shows a satellite
// snapshot of a course, with a flag-on-surface placeholder while loading
// or on failure. Used in the Courses tab list rows and the Home
// "Near You" rows.
//
// Takes primitive lat/lng + a stable cache id rather than a model
// object so it works for both `GolfCourse` (SwiftData) and
// `NearbyCourse` (Sendable struct used by Home).

import SwiftUI
import UIKit

struct CourseHeroImage: View {
    let latitude: Double
    let longitude: Double
    let cacheID: String
    let size: CGSize
    var cornerRadius: CGFloat = 10

    @State private var image: UIImage?
    @State private var didLoad = false

    var body: some View {
        ZStack {
            // Placeholder — also visible during the brief load window
            // and any time the snapshot fails. Solid surface + flag
            // glyph keeps the layout stable.
            if image == nil {
                placeholder
            }
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            }
        }
        .frame(width: size.width, height: size.height)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        .task(id: cacheID) {
            // Re-fetch when the cacheID changes (e.g. recycled row in a
            // List points at a different course).
            guard !didLoad else { return }
            didLoad = true
            let result = await CourseImageService.shared.image(
                latitude: latitude,
                longitude: longitude,
                cacheID: cacheID,
                size: CGSize(
                    width: size.width * UIScreen.main.scale,
                    height: size.height * UIScreen.main.scale
                )
            )
            self.image = result
        }
    }

    private var placeholder: some View {
        ZStack {
            Theme.surface
            Image(systemName: "flag.fill")
                .font(.system(size: min(size.width, size.height) * 0.32))
                .foregroundStyle(Theme.textMuted.opacity(0.5))
        }
    }
}
