import CoreImage
import CoreImage.CIFilterBuiltins

/// Prepares CAPTCHAs drawn as bold glyphs under thin strike lines and speckles for OCR.
public enum ImageCleaner {
    /// Images are scaled to this height first; `strokeRadius` is tuned for it.
    static let targetHeight: CGFloat = 210
    /// Dark strokes thinner than about twice this many pixels (at `targetHeight`) are erased.
    static let strokeRadius: Float = 4

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
        let binary = threshold.outputImage!

        let margin = CIImage(color: .white).cropped(to: binary.extent.insetBy(dx: -40, dy: -40))
        return binary.composited(over: margin)
    }
}
