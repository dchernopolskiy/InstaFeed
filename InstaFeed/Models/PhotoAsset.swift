//
//  PhotoAsset.swift
//  InstaFeed
//
//  Created by Dan Chernopolskii on 5/8/25.
//


import Photos
import UIKit

class PhotoAsset {
    // MARK: - Properties
    let asset: PHAsset
    let identifier: String
    var averageColor: UIColor?
    var dominantColor: UIColor?
    var similarityValue: CGFloat = 1.0
    var isAnalyzed: Bool = false
    
    // MARK: - Initialization
    init(asset: PHAsset) {
        self.asset = asset
        self.identifier = asset.localIdentifier
    }
    
    // MARK: - Equality
    static func == (lhs: PhotoAsset, rhs: PhotoAsset) -> Bool {
        return lhs.identifier == rhs.identifier
    }
    
    // MARK: - Color Analysis
    func analyzeColor(completion: @escaping (Bool) -> Void) {
        if isAnalyzed {
            completion(true)
            return
        }
        
        let options = PHImageRequestOptions()
        options.deliveryMode = .fastFormat
        options.resizeMode = .fast
        options.isNetworkAccessAllowed = false
        
        let targetSize = CGSize(width: 100, height: 100)
        
        PHImageManager.default().requestImage(for: asset, targetSize: targetSize, contentMode: .aspectFill, options: options) { [weak self] image, info in
            guard let self = self, let image = image else {
                completion(false)
                return
            }
            
            DispatchQueue.global(qos: .userInitiated).async {
                // Extract average color
                if let avgColor = image.averageColor() {
                    self.averageColor = avgColor
                }
                
                // Extract dominant color using KMeans if available
                if let kmeans = KMeansCluster(image: image, colorCount: 3) {
                    self.dominantColor = kmeans.dominantColor()
                }
                
                self.isAnalyzed = true
                
                DispatchQueue.main.async {
                    completion(true)
                }
            }
        }
    }
}
