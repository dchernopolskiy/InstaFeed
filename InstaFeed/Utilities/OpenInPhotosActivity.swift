//
//  OpenInPhotosActivity.swift
//  InstaFeed
//
//  Created by Dan Chernopolskii on 5/8/25.
//


import UIKit
import Photos

class OpenInPhotosActivity: UIActivity {
    static let activityType = UIActivity.ActivityType("com.instafeed.openInPhotos")
    
    // Handler to call when activity is performed
    var completionHandler: (() -> Void)?
    
    override var activityTitle: String? {
        return "Open in Photos"
    }
    
    override var activityImage: UIImage? {
        return UIImage(systemName: "photo")
    }
    
    override var activityType: UIActivity.ActivityType? {
        return OpenInPhotosActivity.activityType
    }
    
    override class var activityCategory: UIActivity.Category {
        return .action
    }
    
    override func canPerform(withActivityItems activityItems: [Any]) -> Bool {
        return activityItems.contains { $0 is UIImage }
    }
    
    override func prepare(withActivityItems activityItems: [Any]) {
        // Nothing to prepare
    }
    
    override func perform() {
        completionHandler?()
        activityDidFinish(true)
    }
}
