// ColorWheelView.swift
import UIKit

protocol ColorWheelViewDelegate: AnyObject {
    func colorWheelView(_ colorWheel: ColorWheelView, didSelectColor color: UIColor)
    func colorWheelView(_ colorWheel: ColorWheelView, didUpdateColor color: UIColor, withGesture gesture: UILongPressGestureRecognizer)
}

class ColorWheelView: UIView {
    
    // MARK: - UI Elements
    private let colorWheelLayer = CAGradientLayer()
    private let maskLayer = CAShapeLayer()
    private let innerCircleView = UIView()
    public let selectorIndicator = UIView()
    
    // MARK: - Properties
    weak var delegate: ColorWheelViewDelegate?
    private let innerCircleRatio: CGFloat = 0.52 // Ratio of inner circle to wheel radius
    
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
        updateLayers()
    }
    
    // MARK: - Setup
    private func setupView() {
        backgroundColor = .clear
        layer.cornerRadius = bounds.width / 2
        clipsToBounds = true
        
        // Setup color wheel layer
        colorWheelLayer.type = .conic
        colorWheelLayer.colors = [
            UIColor.red.cgColor,
            UIColor.yellow.cgColor,
            UIColor.green.cgColor,
            UIColor.cyan.cgColor,
            UIColor.blue.cgColor,
            UIColor.magenta.cgColor,
            UIColor.red.cgColor
        ]
        colorWheelLayer.startPoint = CGPoint(x: 0.5, y: 0.5)
        colorWheelLayer.endPoint = CGPoint(x: 0.5, y: 0)
        layer.addSublayer(colorWheelLayer)
        
        // Setup mask layer
        layer.mask = maskLayer
        
        // Setup inner circle
        innerCircleView.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        innerCircleView.layer.cornerRadius = bounds.width * innerCircleRatio / 2
        addSubview(innerCircleView)
        
        // Setup selector indicator
        selectorIndicator.frame = CGRect(x: 0, y: 0, width: 24, height: 24)
        selectorIndicator.layer.cornerRadius = 12
        selectorIndicator.layer.borderWidth = 2
        selectorIndicator.layer.borderColor = UIColor.white.cgColor
        selectorIndicator.alpha = 0
        addSubview(selectorIndicator)
        
        // Add shadow
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.5
        layer.shadowOffset = CGSize(width: 0, height: 4)
        layer.shadowRadius = 8
        layer.masksToBounds = false
        
        updateLayers()
    }
    
    private func updateLayers() {
        // Update layers based on current size
        colorWheelLayer.frame = bounds
        
        // Create mask path for ring shape
        let path = UIBezierPath(ovalIn: bounds)
        let innerCircleSize = bounds.width * innerCircleRatio
        let innerCircleRect = CGRect(
            x: (bounds.width - innerCircleSize) / 2,
            y: (bounds.height - innerCircleSize) / 2,
            width: innerCircleSize,
            height: innerCircleSize
        )
        let innerPath = UIBezierPath(ovalIn: innerCircleRect)
        path.append(innerPath.reversing())
        maskLayer.path = path.cgPath
        
        // Update inner circle
        innerCircleView.frame = innerCircleRect
        innerCircleView.layer.cornerRadius = innerCircleSize / 2
    }
    
    // MARK: - Public Methods
    func show(animated: Bool = true) {
        if animated {
            alpha = 0
            transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
            
            UIView.animate(withDuration: 0.25, delay: 0, usingSpringWithDamping: 0.7, initialSpringVelocity: 0.5, options: [], animations: {
                self.alpha = 1.0
                self.transform = CGAffineTransform.identity
            })
        } else {
            alpha = 1.0
        }
    }
    
    func hide(animated: Bool = true) {
        if animated {
            UIView.animate(withDuration: 0.2, animations: {
                self.alpha = 0
                self.selectorIndicator.alpha = 0
            })
        } else {
            alpha = 0
            selectorIndicator.alpha = 0
        }
    }
    
    func updateSelector(at point: CGPoint) -> UIColor? {
        // Check if point is within the ring
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        let distance = hypot(point.x - center.x, point.y - center.y)
        let outerRadius = bounds.width / 2
        let innerRadius = outerRadius * innerCircleRatio
        
        if distance <= outerRadius && distance >= innerRadius {
            // Position selector
            selectorIndicator.center = point
            selectorIndicator.alpha = 1.0
            
            // Get color at this position
            let color = getColorAt(point)
            selectorIndicator.backgroundColor = color
            
            return color
        }
        
        return nil
    }
    
    func getColorAt(_ point: CGPoint) -> UIColor {
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        
        // Convert to angle in radians
        let deltaX = point.x - center.x
        let deltaY = point.y - center.y
        var angle = atan2(deltaY, deltaX)
        
        // Normalize to 0-2π
        if angle < 0 {
            angle += 2 * .pi
        }
        
        // Map angle to hue (0-1)
        var hue = angle / (2 * .pi)
        
        // Rotate the hue by 0.25 (90 degrees) to align with the visual color wheel
        // This puts red at the top (0 degrees/hue 0)
        hue = (hue + 0.25).truncatingRemainder(dividingBy: 1.0)
        
        // Log for debugging
        print("🎨 Point: \(point), Angle: \(angle), Original Hue: \(angle / (2 * .pi)), Adjusted Hue: \(hue)")
        
        return UIColor(hue: hue, saturation: 1.0, brightness: 1.0, alpha: 1.0)
    }
}
