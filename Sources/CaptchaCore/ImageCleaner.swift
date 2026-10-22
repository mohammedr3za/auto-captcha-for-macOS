import CoreImage
import CoreImage.CIFilterBuiltins

/// Prepares CAPTCHAs drawn as bold glyphs under thin strike lines and speckles for OCR.
public enum ImageCleaner {
    /// Images are scaled to this height first; `strokeRadius` is tuned for it.
    static let targetHeight: CGFloat = 210
    /// Dark strokes thinner than about twice this many pixels (at `targetHeight`) are erased.
    /// 4 left fragments of a real site's strike lines on a T, which then read as 7.
    static let strokeRadius: Float = 5

    /// Grayscale, scale, erase thin strokes, black and white, white margin.
    public static func clean(_ input: CIImage) -> CIImage {
        let image = input.transformed(by: .init(translationX: -input.extent.minX, y: -input.extent.minY))

        let gray = CIFilter.colorControls()
        gray.inputImage = image
        gray.saturation = 0

        let scale = CIFilter.lanczosScaleTransform()
        scale.inputImage = gray.outputImage
        scale.scale = Float(targetHeight / max(image.extent.height, 1))
        scale.aspectRatio = 1
        let scaled = scale.outputImage!

        // Max then min over dark-on-light content is a morphological opening of the dark parts.
        let dilate = CIFilter.morphologyMaximum()
        dilate.inputImage = scaled.clampedToExtent()
        dilate.radius = strokeRadius
        let erode = CIFilter.morphologyMinimum()
        erode.inputImage = dilate.outputImage
        erode.radius = strokeRadius

        let threshold = CIFilter.colorThreshold()
        threshold.inputImage = erode.outputImage!.cropped(to: scaled.extent)
        threshold.threshold = 0.5
        return withMargin(threshold.outputImage!, 40)
    }

    /// Surrounds the image with white. Vision drops characters that touch the image edge.
    public static func withMargin(_ input: CIImage, _ margin: CGFloat) -> CIImage {
        let image = input.transformed(by: .init(translationX: -input.extent.minX, y: -input.extent.minY))
        let canvas = CIImage(color: .white).cropped(to: image.extent.insetBy(dx: -margin, dy: -margin))
        return image.composited(over: canvas)
    }
}
