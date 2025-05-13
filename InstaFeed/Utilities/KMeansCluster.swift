//
//  KMeansCluster.swift
//  InstaFeed
//
//  Created by Dan Chernopolskii on 5/8/25.
//


import UIKit

class KMeansCluster {
    // MARK: - Properties
    private var image: UIImage
    private var colorCount: Int
    private var pixelColors: [UIColor] = []
    private var clusters: [UIColor] = []
    
    // MARK: - Initialization
    init?(image: UIImage, colorCount: Int = 5) {
        self.image = image
        self.colorCount = colorCount
        
        // Extract pixel colors from image
        if !extractPixelColors() {
            return nil
        }
        
        // Run clustering
        runKMeans()
    }
    
    // MARK: - Public Methods
    func dominantColor() -> UIColor? {
        // Return the most dominant color from clusters
        return clusters.first
    }
    
    func palette() -> [UIColor] {
        return clusters
    }
    
    // MARK: - Private Methods
    private func extractPixelColors() -> Bool {
        guard let cgImage = image.cgImage else { return false }
        
        // Downsample for performance
        let downsampleFactor = 10
        let width = cgImage.width / downsampleFactor
        let height = cgImage.height / downsampleFactor
        
        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * width
        
        let bitsPerComponent = 8
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
        
        guard let context = CGContext(data: nil,
                                     width: width,
                                     height: height,
                                     bitsPerComponent: bitsPerComponent,
                                     bytesPerRow: bytesPerRow,
                                     space: colorSpace,
                                     bitmapInfo: bitmapInfo),
              let ptr = context.data else {
            return false
        }
        
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        let buffer = ptr.bindMemory(to: UInt32.self, capacity: width * height)
        
        for y in 0..<height {
            for x in 0..<width {
                let offset = y * width + x
                let pixel = buffer[offset]
                
                // Extract RGB components
                let r = CGFloat((pixel >> 16) & 0xFF) / 255.0
                let g = CGFloat((pixel >> 8) & 0xFF) / 255.0
                let b = CGFloat(pixel & 0xFF) / 255.0
                
                // Skip transparent or very dark pixels
                let threshold: CGFloat = 0.1
                if r > threshold || g > threshold || b > threshold {
                    pixelColors.append(UIColor(red: r, green: g, blue: b, alpha: 1.0))
                }
            }
        }
        
        // Take a sample for performance
        if pixelColors.count > 1000 {
            let strideSize = pixelColors.count / 1000
            pixelColors = stride(from: 0, to: pixelColors.count, by: strideSize).map { pixelColors[$0] }
        }
        
        return pixelColors.count > 0
    }
    
    private func runKMeans() {
        // Initialize clusters with random colors
        clusters = (0..<colorCount).map { _ in
            if let randomIndex = (0..<pixelColors.count).randomElement() {
                return pixelColors[randomIndex]
            }
            return .black
        }
        
        // Maximum iterations
        let maxIterations = 10
        
        for _ in 0..<maxIterations {
            // Assignment step
            var assignments: [[UIColor]] = Array(repeating: [], count: colorCount)
            
            for color in pixelColors {
                var minDistance = CGFloat.greatestFiniteMagnitude
                var closestCluster = 0
                
                for (i, cluster) in clusters.enumerated() {
                    let distance = colorDistance(color, cluster)
                    if distance < minDistance {
                        minDistance = distance
                        closestCluster = i
                    }
                }
                
                assignments[closestCluster].append(color)
            }
            
            // Update step
            var newClusters: [UIColor] = []
            
            for clusterColors in assignments {
                if clusterColors.isEmpty {
                    // If cluster is empty, keep the old center
                    if let randomIndex = (0..<pixelColors.count).randomElement() {
                        newClusters.append(pixelColors[randomIndex])
                    } else {
                        newClusters.append(.black)
                    }
                } else {
                    // Calculate new center
                    let avgColor = averageColor(clusterColors)
                    newClusters.append(avgColor)
                }
            }
            
            // Check for convergence
            var converged = true
            for i in 0..<colorCount {
                if colorDistance(clusters[i], newClusters[i]) > 0.01 {
                    converged = false
                    break
                }
            }
            
            clusters = newClusters
            
            if converged {
                break
            }
        }
        
        // Sort clusters by brightness (darker to brighter)
        clusters.sort { color1, color2 in
            var white1: CGFloat = 0
            var white2: CGFloat = 0
            color1.getWhite(&white1, alpha: nil)
            color2.getWhite(&white2, alpha: nil)
            return white1 > white2
        }
    }
    
    private func colorDistance(_ color1: UIColor, _ color2: UIColor) -> CGFloat {
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
        
        color1.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        color2.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        
        let rDiff = r1 - r2
        let gDiff = g1 - g2
        let bDiff = b1 - b2
        
        return sqrt(rDiff * rDiff + gDiff * gDiff + bDiff * bDiff)
    }
    
    private func averageColor(_ colors: [UIColor]) -> UIColor {
        var totalRed: CGFloat = 0
        var totalGreen: CGFloat = 0
        var totalBlue: CGFloat = 0
        
        for color in colors {
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            color.getRed(&r, green: &g, blue: &b, alpha: &a)
            
            totalRed += r
            totalGreen += g
            totalBlue += b
        }
        
        let count = CGFloat(colors.count)
        return UIColor(red: totalRed / count, green: totalGreen / count, blue: totalBlue / count, alpha: 1.0)
    }
}
