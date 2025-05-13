//
//  ColorAnalysis.swift
//  InstaFeed
//
//  Created by Dan Chernopolskii on 5/7/25.
//

import UIKit
import CoreImage
import Photos

class ColorAnalysis {
    
    // MARK: - Singleton
    static let shared = ColorAnalysis()
    
    // MARK: - Properties
    private var colorCache: [String: UIColor] = [:]
    private let analysisQueue = DispatchQueue(label: "com.instafeed.coloranalysis", qos: .userInitiated, attributes: .concurrent)
    
    // MARK: - Public Methods
    
    /// Extract the average color from a PHAsset
    func averageColor(for asset: PHAsset, completion: @escaping (UIColor?) -> Void) {
        // Check cache first
        if let cachedColor = colorCache[asset.localIdentifier] {
            completion(cachedColor)
            return
        }
        
        // Request thumbnail and analyze
        let manager = PHImageManager.default()
        let options = PHImageRequestOptions()
        options.deliveryMode = .fastFormat
        options.resizeMode = .fast
        options.isNetworkAccessAllowed = false
        
        let targetSize = CGSize(width: 100, height: 100)
        
        manager.requestImage(for: asset, targetSize: targetSize, contentMode: .aspectFill, options: options) { [weak self] image, info in
            guard let self = self, let image = image else {
                completion(nil)
                return
            }
            
            self.analysisQueue.async {
                let color = self.extractAverageColor(from: image)
                
                // Cache the result
                if let color = color {
                    self.colorCache[asset.localIdentifier] = color
                }
                
                DispatchQueue.main.async {
                    completion(color)
                }
            }
        }
    }
    
    /// Calculate similarity between two colors (0-1 range, lower is more similar)
    func calculateSimilarity(between color1: UIColor, and color2: UIColor, method: SimilarityMethod = .color) -> CGFloat {
        switch method {
        case .color:
            return colorSimilarity(color1, color2)
        case .shade:
            return shadeSimilarity(color1, color2)
        }
    }
    
    /// Analyze multiple assets in batch
    func analyzeBatch(assets: [PHAsset], progress: ((Float) -> Void)? = nil, completion: @escaping ([String: UIColor]) -> Void) {
        var results: [String: UIColor] = [:]
        let group = DispatchGroup()
        let lock = NSLock()
        var processedCount: Int = 0
        
        for asset in assets {
            // Skip if already cached
            if let cachedColor = colorCache[asset.localIdentifier] {
                lock.lock()
                results[asset.localIdentifier] = cachedColor
                lock.unlock()
                
                processedCount += 1
                progress?(Float(processedCount) / Float(assets.count))
                continue
            }
            
            group.enter()
            averageColor(for: asset) { color in
                if let color = color {
                    lock.lock()
                    results[asset.localIdentifier] = color
                    lock.unlock()
                }
                
                processedCount += 1
                progress?(Float(processedCount) / Float(assets.count))
                group.leave()
            }
        }
        
        group.notify(queue: .main) {
            completion(results)
        }
    }
    
    /// Save the color cache
    func saveColorCache() {
        var cacheData: [String: [String: CGFloat]] = [:]
        
        for (identifier, color) in colorCache {
            var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
            color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
            cacheData[identifier] = ["red": red, "green": green, "blue": blue]
        }
        
        if let encodedData = try? JSONEncoder().encode(cacheData) {
            UserDefaults.standard.set(encodedData, forKey: "ColorCache")
        }
    }
    
    /// Load the color cache
    func loadColorCache() {
        if let cachedData = UserDefaults.standard.data(forKey: "ColorCache"),
           let cachedResults = try? JSONDecoder().decode([String: [String: CGFloat]].self, from: cachedData) {
            
            for (identifier, colorData) in cachedResults {
                if let red = colorData["red"],
                   let green = colorData["green"],
                   let blue = colorData["blue"] {
                    colorCache[identifier] = UIColor(red: red, green: green, blue: blue, alpha: 1.0)
                }
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func extractAverageColor(from image: UIImage) -> UIColor? {
        guard let inputImage = CIImage(image: image) else { return nil }
        
        let extentVector = CIVector(x: inputImage.extent.origin.x,
                                   y: inputImage.extent.origin.y,
                                   z: inputImage.extent.size.width,
                                   w: inputImage.extent.size.height)
        
        guard let filter = CIFilter(name: "CIAreaAverage", parameters: [kCIInputImageKey: inputImage, kCIInputExtentKey: extentVector]) else { return nil }
        guard let outputImage = filter.outputImage else { return nil }
        
        var bitmap = [UInt8](repeating: 0, count: 4)
        let context = CIContext(options: [.workingColorSpace: kCFNull as Any])
        
        context.render(outputImage, toBitmap: &bitmap, rowBytes: 4, bounds: CGRect(x: 0, y: 0, width: 1, height: 1), format: .RGBA8, colorSpace: nil)
        
        return UIColor(red: CGFloat(bitmap[0]) / 255,
                      green: CGFloat(bitmap[1]) / 255,
                      blue: CGFloat(bitmap[2]) / 255,
                      alpha: CGFloat(bitmap[3]) / 255)
    }
    
    // Color similarity calculation
    private func colorSimilarity(_ color1: UIColor, _ color2: UIColor) -> CGFloat {
        var h1: CGFloat = 0, s1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var h2: CGFloat = 0, s2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
        
        color1.getHue(&h1, saturation: &s1, brightness: &b1, alpha: &a1)
        color2.getHue(&h2, saturation: &s2, brightness: &b2, alpha: &a2)
        
        // Calculate hue distance (considering the color wheel is circular)
        var hueDiff = abs(h1 - h2)
        if hueDiff > 0.5 {
            hueDiff = 1.0 - hueDiff
        }
        
        // Weight the components with higher emphasis on hue matching
        return (hueDiff * 0.7) + (abs(s1 - s2) * 0.2) + (abs(b1 - b2) * 0.1)
    }
    
    // Shade (brightness) similarity calculation
    private func shadeSimilarity(_ color1: UIColor, _ color2: UIColor) -> CGFloat {
        var white1: CGFloat = 0, alpha1: CGFloat = 0
        var white2: CGFloat = 0, alpha2: CGFloat = 0
        
        let success1 = color1.getWhite(&white1, alpha: &alpha1)
        let success2 = color2.getWhite(&white2, alpha: &alpha2)
        
        if !success1 || !success2 {
            // If colors can't be expressed as white, convert to grayscale first
            var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
            var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
            
            color1.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
            color2.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
            
            // Calculate perceived brightness using standard luminance formula
            white1 = (r1 * 0.299) + (g1 * 0.587) + (b1 * 0.114)
            white2 = (r2 * 0.299) + (g2 * 0.587) + (b2 * 0.114)
        }
        
        return abs(white1 - white2)
    }
}

// Sorting methods enum
enum SimilarityMethod {
    case color  // Compare by color (hue-based)
    case shade  // Compare by brightness
}

extension ColorAnalysis {
    func getCachedColors() -> [String: UIColor] {
        // Return the dictionary of cached colors
        return self.colorCache
    }
}
