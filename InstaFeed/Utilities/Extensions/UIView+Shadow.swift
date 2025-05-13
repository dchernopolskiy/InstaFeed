//
//  UIView+Shadow.swift
//  InstaFeed
//
//  Created by Dan Chernopolskii on 5/8/25.
//


import UIKit

extension UIView {
    func addFloatingShadow(
        color: UIColor = .black,
        opacity: Float = 0.5,
        offset: CGSize = CGSize(width: 0, height: 3),
        radius: CGFloat = 5.0
    ) {
        layer.shadowColor = color.cgColor
        layer.shadowOpacity = opacity
        layer.shadowOffset = offset
        layer.shadowRadius = radius
        layer.masksToBounds = false
        
        // Optimize shadow rendering for performance
        layer.shouldRasterize = true
        layer.rasterizationScale = UIScreen.main.scale
    }
    
    func addInnerShadow(
        color: UIColor = .black,
        opacity: Float = 0.5,
        radius: CGFloat = 3.0
    ) {
        // Create inner shadow layer
        let innerShadow = CALayer()
        innerShadow.frame = bounds
        
        // Shadow properties
        let path = UIBezierPath(rect: innerShadow.bounds.insetBy(dx: -radius, dy: -radius))
        let cutout = UIBezierPath(rect: innerShadow.bounds).reversing()
        path.append(cutout)
        
        innerShadow.shadowPath = path.cgPath
        innerShadow.masksToBounds = true
        innerShadow.shadowColor = color.cgColor
        innerShadow.shadowOffset = CGSize.zero
        innerShadow.shadowOpacity = opacity
        innerShadow.shadowRadius = radius
        innerShadow.cornerRadius = layer.cornerRadius
        
        // Add inner shadow layer
        layer.addSublayer(innerShadow)
    }
    
    func removeShadows() {
        layer.shadowOpacity = 0
        layer.shadowRadius = 0
        layer.shadowOffset = .zero
        layer.shadowPath = nil
        layer.shouldRasterize = false
    }
}
