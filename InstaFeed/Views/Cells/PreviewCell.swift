//
//  PreviewCell.swift
//  InstaFeed
//
//  Created by Dan Chernopolskii on 5/8/25.
//


import UIKit
import Photos

class PreviewCell: UICollectionViewCell {
    // MARK: - UI Elements
    let imageView = UIImageView()
    let tintOverlay = UIView()
    let numberLabel = UILabel()
    
    // MARK: - Initialization
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }
    
    // MARK: - Setup
    private func setupView() {
        // Setup imageView
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        contentView.addSubview(imageView)
        
        // Setup tint overlay
        tintOverlay.backgroundColor = UIColor(white: 0, alpha: 0.3)
        contentView.addSubview(tintOverlay)
        
        // Setup number label
        numberLabel.textColor = .white
        numberLabel.font = UIFont.systemFont(ofSize: 12, weight: .bold)
        numberLabel.textAlignment = .center
        numberLabel.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        numberLabel.layer.cornerRadius = 8
        numberLabel.clipsToBounds = true
        contentView.addSubview(numberLabel)
        
        // Apply constraints
        imageView.translatesAutoresizingMaskIntoConstraints = false
        tintOverlay.translatesAutoresizingMaskIntoConstraints = false
        numberLabel.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: contentView.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            
            tintOverlay.topAnchor.constraint(equalTo: contentView.topAnchor),
            tintOverlay.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            tintOverlay.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            tintOverlay.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            
            numberLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 4),
            numberLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 4),
            numberLabel.widthAnchor.constraint(equalToConstant: 16),
            numberLabel.heightAnchor.constraint(equalToConstant: 16)
        ])
    }
    
    // MARK: - Configuration
    func configure(with asset: PHAsset, color: UIColor?, index: Int) {
        // Reset cell
        imageView.image = nil
        tintOverlay.backgroundColor = UIColor(white: 0, alpha: 0.3)
        
        // Set number label
        numberLabel.text = "\(index + 1)"
        
        // Apply tint color if available
        if let color = color {
            tintOverlay.backgroundColor = color.withAlphaComponent(0.3)
        }
        
        // Load thumbnail
        let size = CGSize(width: bounds.width * UIScreen.main.scale, height: bounds.height * UIScreen.main.scale)
        
        PHImageManager.default().requestImage(
            for: asset,
            targetSize: size,
            contentMode: .aspectFill,
            options: nil
        ) { [weak self] image, _ in
            DispatchQueue.main.async {
                self?.imageView.image = image
            }
        }
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        imageView.image = nil
        tintOverlay.backgroundColor = UIColor(white: 0, alpha: 0.3)
        numberLabel.text = ""
    }
}
