//
//  PhotoCell.swift
//  InstaFeed
//
//  Created by Dan Chernopolskii on 5/7/25.
//


import UIKit
import Photos

class PhotoCell: UICollectionViewCell {
    
    // MARK: - UI Elements
    let imageView = UIImageView()
    let colorIndicator = UIView()
    let similarityLabel = UILabel()
    
    // MARK: - Properties
    private var requestID: PHImageRequestID?
    private let imageManager = PHImageManager.default()
    
    // MARK: - Initialization
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }
    
    // MARK: - View Setup
    private func setupView() {
        // Setup imageView
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        contentView.addSubview(imageView)
        
        // Setup color indicator
        colorIndicator.layer.cornerRadius = 4
        colorIndicator.layer.borderWidth = 1
        colorIndicator.layer.borderColor = UIColor.white.cgColor
        colorIndicator.isHidden = true
        contentView.addSubview(colorIndicator)
        
        // Setup similarity label (optional)
        similarityLabel.font = UIFont.systemFont(ofSize: 10)
        similarityLabel.textColor = .white
        similarityLabel.textAlignment = .right
        similarityLabel.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        similarityLabel.layer.cornerRadius = 4
        similarityLabel.clipsToBounds = true
        similarityLabel.isHidden = true // Hidden by default
        contentView.addSubview(similarityLabel)
        
        // Apply constraints
        imageView.translatesAutoresizingMaskIntoConstraints = false
        colorIndicator.translatesAutoresizingMaskIntoConstraints = false
        similarityLabel.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: contentView.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            
            colorIndicator.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 4),
            colorIndicator.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -4),
            colorIndicator.widthAnchor.constraint(equalToConstant: 8),
            colorIndicator.heightAnchor.constraint(equalToConstant: 8),
            
            similarityLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -4),
            similarityLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -4),
            similarityLabel.leadingAnchor.constraint(greaterThanOrEqualTo: contentView.leadingAnchor, constant: 4)
        ])
    }
    
    // MARK: - Configuration
    func configure(with asset: PHAsset, color: UIColor?, similarity: CGFloat? = nil) {
        // Cancel any previous requests
        if let requestID = requestID {
            imageManager.cancelImageRequest(requestID)
        }
        
        // Reset cell
        imageView.image = nil
        colorIndicator.backgroundColor = nil
        colorIndicator.isHidden = color == nil
        
        // Configure color indicator
        if let color = color {
            colorIndicator.backgroundColor = color
            colorIndicator.isHidden = false
        }
        
        // Set similarity if provided
        if let similarity = similarity {
            similarityLabel.text = String(format: "%.2f", similarity)
            similarityLabel.isHidden = false
        } else {
            similarityLabel.isHidden = true
        }
        
        // Load thumbnail
        let size = CGSize(width: bounds.width * UIScreen.main.scale, height: bounds.height * UIScreen.main.scale)
        let options = PHImageRequestOptions()
        options.deliveryMode = .opportunistic
        options.resizeMode = .exact
        options.isNetworkAccessAllowed = true
        
        requestID = imageManager.requestImage(
            for: asset,
            targetSize: size,
            contentMode: .aspectFill,
            options: options
        ) { [weak self] image, info in
            guard let self = self, let image = image else { return }
            
            DispatchQueue.main.async {
                // Fade in image for smoother loading
                UIView.transition(with: self.imageView, duration: 0.2, options: .transitionCrossDissolve, animations: {
                    self.imageView.image = image
                })
            }
        }
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        
        // Cancel any pending image requests
        if let requestID = requestID {
            imageManager.cancelImageRequest(requestID)
            self.requestID = nil
        }
        
        imageView.image = nil
        colorIndicator.backgroundColor = nil
        colorIndicator.isHidden = true
        similarityLabel.isHidden = true
    }
}
