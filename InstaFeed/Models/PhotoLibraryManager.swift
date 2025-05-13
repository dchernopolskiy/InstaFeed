//
//  PhotoLibraryManagerDelegate.swift
//  InstaFeed
//
//  Created by Dan Chernopolskii on 5/7/25.
//


import Photos
import UIKit

protocol PhotoLibraryManagerDelegate: AnyObject {
    func photoLibraryManager(_ manager: PhotoLibraryManager, didUpdateAuth status: PHAuthorizationStatus)
    func photoLibraryManager(_ manager: PhotoLibraryManager, didFetchAssets assets: PHFetchResult<PHAsset>)
    func photoLibraryManager(_ manager: PhotoLibraryManager, didFailWithError error: Error)
}

class PhotoLibraryManager {
    
    // MARK: - Singleton
    static let shared = PhotoLibraryManager()
    
    // MARK: - Properties
    weak var delegate: PhotoLibraryManagerDelegate?
    
    var allPhotos: PHFetchResult<PHAsset>?
    var selectedCollection: PHAssetCollection?
    
    // MARK: - Public Methods
    
    /// Request authorization to access photo library
    func requestAuthorization() {
        PHPhotoLibrary.requestAuthorization { [weak self] status in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                self.delegate?.photoLibraryManager(self, didUpdateAuth: status)
                
                if status == .authorized {
                    self.fetchAllPhotos()
                }
            }
        }
    }
    
    /// Fetch all photos from the library
    func fetchAllPhotos() {
        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        
        if let selectedCollection = selectedCollection {
            // Fetch from specific collection
            let assets = PHAsset.fetchAssets(in: selectedCollection, options: fetchOptions)
            print("📁 Fetched \(assets.count) photos from collection: \(selectedCollection.localizedTitle ?? "Unknown")")
            allPhotos = assets
            delegate?.photoLibraryManager(self, didFetchAssets: assets)
        } else {
            // Fetch all photos
            let assets = PHAsset.fetchAssets(with: .image, options: fetchOptions)
            print("📁 Fetched \(assets.count) photos from All Photos")
            allPhotos = assets
            delegate?.photoLibraryManager(self, didFetchAssets: assets)
        }
    }
    
    /// Fetch user's albums
    func fetchAlbums(completion: @escaping ([PHAssetCollection]) -> Void) {
        var albums: [PHAssetCollection] = []
        
        // User albums
        let userAlbums = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .any, options: nil)
        userAlbums.enumerateObjects { (collection, _, _) in
            albums.append(collection)
        }
        
        // Smart albums (like Camera Roll, Favorites, etc.)
        let smartAlbums = PHAssetCollection.fetchAssetCollections(with: .smartAlbum, subtype: .any, options: nil)
        smartAlbums.enumerateObjects { (collection, _, _) in
            albums.append(collection)
        }
        
        completion(albums)
    }
    
    /// Set the selected collection and fetch its photos
    func selectCollection(_ collection: PHAssetCollection?) {
        print("📁 Selecting collection: \(collection?.localizedTitle ?? "All Photos")")
        selectedCollection = collection
        fetchAllPhotos()
    }
    
    /// Load thumbnail for a PHAsset
    func loadThumbnail(for asset: PHAsset, size: CGSize, contentMode: PHImageContentMode = .aspectFill, completion: @escaping (UIImage?) -> Void) {
        let manager = PHImageManager.default()
        let options = PHImageRequestOptions()
        options.deliveryMode = .opportunistic
        options.isNetworkAccessAllowed = true
        
        manager.requestImage(for: asset, targetSize: size, contentMode: contentMode, options: options) { image, _ in
            DispatchQueue.main.async {
                completion(image)
            }
        }
    }
    
    /// Load full-size image for a PHAsset
    func loadFullImage(for asset: PHAsset, completion: @escaping (UIImage?) -> Void) {
        let manager = PHImageManager.default()
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.isNetworkAccessAllowed = true
        options.isSynchronous = false
        
        manager.requestImage(for: asset, targetSize: PHImageManagerMaximumSize, contentMode: .aspectFit, options: options) { image, _ in
            DispatchQueue.main.async {
                completion(image)
            }
        }
    }
    
    /// Get PHAsset from local identifier
    func asset(withIdentifier identifier: String) -> PHAsset? {
        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [identifier], options: nil)
        return fetchResult.firstObject
    }
}
