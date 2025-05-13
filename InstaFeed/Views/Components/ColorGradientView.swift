//
//  ColorGradientView.swift
//  InstaFeed
//
//  Created by Dan Chernopolskii on 5/7/25.
//


import UIKit

class ColorGradientView: UIView {
    
    // MARK: - Properties
    private let gradientLayer = CAGradientLayer()
    private var colors: [UIColor] = []
    
    // MARK: - Initialization
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        gradientLayer.frame = bounds
    }
    
    // MARK: - Setup
    private func setupView() {
        // Make view rounded
        layer.cornerRadius = 8
        clipsToBounds = true
        
        // Create gradient layer
        gradientLayer.startPoint = CGPoint(x: 0.0, y: 0.5)
        gradientLayer.endPoint = CGPoint(x: 1.0, y: 0.5)
        gradientLayer.frame = bounds
        layer.addSublayer(gradientLayer)
    }
    
    // MARK: - Public Methods
    func setColors(_ colors: [UIColor]) {
        self.colors = colors
        
        // Create gradient colors
        let cgColors = colors.map { $0.cgColor }
        
        // Update gradient
        if cgColors.isEmpty {
            // If no colors provided, show a placeholder gradient
            gradientLayer.colors = [
                UIColor.darkGray.cgColor,
                UIColor.lightGray.cgColor
            ]
        } else {
            gradientLayer.colors = cgColors
        }
        
        // Ensure smooth transitions
        var locations: [NSNumber] = []
        if cgColors.count > 1 {
            let step = 1.0 / Double(cgColors.count - 1)
            for i in 0..<cgColors.count {
                locations.append(NSNumber(value: step * Double(i)))
            }
        }
        gradientLayer.locations = locations.isEmpty ? nil : locations
    }
    
    func addColor(_ color: UIColor) {
        colors.append(color)
        setColors(colors)
    }
    
    func clearColors() {
        colors.removeAll()
        setColors([])
    }
}
