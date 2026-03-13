//
//  CGImage+Extended.swift
//  LeapModelTesting
//
//  Created by Ben Davis on 3/13/26.
//
import UIKit
import UniformTypeIdentifiers
import CoreGraphics
import Foundation

extension CGImage {
    
    static func downscaledImage(from data: Data, maxDimension: Int) -> CGImage? {
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: maxDimension,
            kCGImageSourceCreateThumbnailWithTransform: true
        ]

        guard let src = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }

        return CGImageSourceCreateThumbnailAtIndex(src, 0, options as CFDictionary)
    }
    
    func scaledImage(noLargerThan maxSize: CGSize?) -> CGImage? {
        guard let maxSize else {
            return self
        }
        let (width, height) = (CGFloat(self.width), CGFloat(self.height))
        
        if width <= maxSize.width && height <= maxSize.height {
            return self
        }
        let wRatio = maxSize.width / width
        let hRatio = maxSize.height / height
        let scaleFactor = min(wRatio, hRatio)
        let newWidth = width * scaleFactor
        let newHeight = height * scaleFactor
        let newSize = CGSize(width: newWidth.rounded(.down), height: newHeight.rounded(.down))
        print("resizing scaled image from (width: \(width), height: \(height)) to (width: \(newSize.width), height: \(newSize.height))")

       
        let context = CGContext(data: nil,
                                width: Int(newSize.width),
                                height: Int(newSize.height),
                                bitsPerComponent: self.bitsPerComponent,
                                bytesPerRow: 0,
                                space: self.colorSpace ?? CGColorSpace(name: CGColorSpace.sRGB)!,
                                bitmapInfo: self.bitmapInfo.rawValue)
        context?.interpolationQuality = .high
        context?.draw(self, in: CGRect(origin: .zero, size: newSize))
        let result = context?.makeImage()
        return result
    }
    
    func jpegData(jpegQuality: CGFloat = 0.8) -> Data? {
        let mutableData = NSMutableData()
        let identifier = UTType.jpeg.identifier as CFString  // Change to JPEG

        guard let imageDestination = CGImageDestinationCreateWithData(mutableData,
                                                                      identifier,
                                                                      1,
                                                                      nil)
        else {
            return nil
        }

        let options = [kCGImageDestinationLossyCompressionQuality: jpegQuality] as CFDictionary
        CGImageDestinationAddImage(imageDestination, self, options)
        CGImageDestinationFinalize(imageDestination)
        #if DEBUG
        print("jpegData(jpegQuality) data size: \((mutableData as Data).count)")
        #endif
        return mutableData as Data
    }

    
    func reorientImage(orientation: CGImagePropertyOrientation, context: CIContext?) -> CGImage? {
        let ciImage = CIImage(cgImage: self).oriented(orientation)  // Correct orientation

        let currentContext = context ?? CIContext(options: nil)  // Create Core Image context
        return currentContext.createCGImage(ciImage, from: ciImage.extent)  // Convert back to CGImage
    }

    
    static func imageFromData(_ data: Data, shouldCache: Bool = true, highPrecision: Bool = true, shouldCorrectOrientation: Bool, context: CIContext) -> CGImage? {
        
        let options: [CFString: Any] = [
            kCGImageSourceShouldCache: shouldCache,   // Cache the image in memory
            kCGImageSourceShouldAllowFloat: highPrecision // Allow high-precision images
        ]

        guard let imageSource = CGImageSourceCreateWithData(data as CFData, nil) else {
            return nil
        }
        
        if !shouldCorrectOrientation {
            return CGImageSourceCreateImageAtIndex(imageSource, 0, options as CFDictionary)
        }
        else {
            let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [CFString: Any]
            let orientationValue = (properties?[kCGImagePropertyOrientation] as? UInt32) ?? 1
            let cgImageOrientation = CGImagePropertyOrientation(rawValue: orientationValue) ?? .up
            
            guard let cgImage = CGImageSourceCreateImageAtIndex(imageSource, 0, options as CFDictionary) else {
                return nil
            }
            
            // Apply orientation correction
            return cgImage.reorientImage(orientation: cgImageOrientation, context: context)


        }
    }

}
