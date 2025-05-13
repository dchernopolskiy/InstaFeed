//
//  CacheManager.swift
//  InstaFeed
//
//  Created by Dan Chernopolskii on 5/8/25.
//


import UIKit
import Photos

class CacheManager {
    // MARK: - Singleton
    static let shared = CacheManager()
    
    // MARK: - Properties
    private let userDefaults = UserDefaults.standard
    private let fileManager = FileManager.default
    private let cacheQueue = DispatchQueue(label: "com.instafeed.cache", qos: .background)
    
    private var memoryColorCache: [String: UIColor] = [:]
    private let cacheKey = "ColorCacheData"
    
    // MARK: - Public Methods
    func setColor(_ color: UIColor, for identifier: String) {
        memoryColorCache[identifier] = color
        saveColorsToDisk()
    }
    
    func color(for identifier: String) -> UIColor? {
        // Check memory cache first
        if let color = memoryColorCache[identifier] {
            return color
        }
        
        return nil
    }
    
    func hasCache(for identifier: String) -> Bool {
        return memoryColorCache[identifier] != nil
    }
    
    func preloadFromDisk() {
        cacheQueue.async { [weak self] in
            guard let self = self else { return }
            self.loadColorsFromDisk()
        }
    }
    
    func clearCache() {
        memoryColorCache.removeAll()
        userDefaults.removeObject(forKey: cacheKey)
    }
    
    func getCachedColors() -> [String: UIColor] {
        return memoryColorCache
    }
    
    // MARK: - Serialization
    func saveColorsToDisk() {
        cacheQueue.async { [weak self] in
            guard let self = self else { return }
            
            var cacheData: [String: [String: CGFloat]] = [:]
            
            for (identifier, color) in self.memoryColorCache {
                var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
                color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
                cacheData[identifier] = ["red": red, "green": green, "blue": blue]
            }
            
            if let data = try? JSONEncoder().encode(cacheData) {
                self.userDefaults.set(data, forKey: self.cacheKey)
            }
        }
    }
    
    private func loadColorsFromDisk() {
        if let data = userDefaults.data(forKey: cacheKey),
           let cacheData = try? JSONDecoder().decode([String: [String: CGFloat]].self, from: data) {
            
            for (identifier, colorComponents) in cacheData {
                if let red = colorComponents["red"],
                   let green = colorComponents["green"],
                   let blue = colorComponents["blue"] {
                    
                    let color = UIColor(red: red, green: green, blue: blue, alpha: 1.0)
                    memoryColorCache[identifier] = color
                }
            }
        }
    }
}
