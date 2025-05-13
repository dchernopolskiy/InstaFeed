import UIKit

extension UIColor {
    // Calculate perceptual distance between colors
    func distance(to color: UIColor) -> CGFloat {
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
        
        self.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        color.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        
        // Using weighted Euclidean distance to account for human perception
        let rMean = (r1 + r2) / 2
        let rDiff = r1 - r2
        let gDiff = g1 - g2
        let bDiff = b1 - b2
        
        // Weights based on human perception
        let rWeight = 2.0 + rMean
        let gWeight = 4.0
        let bWeight = 2.0 + (1.0 - rMean)
        
        let distance = sqrt(
            rWeight * rDiff * rDiff +
            gWeight * gDiff * gDiff +
            bWeight * bDiff * bDiff
        )
        
        return distance
    }
    
    // Calculate brightness of the color (0-1)
    var brightness: CGFloat {
        var white: CGFloat = 0
        var alpha: CGFloat = 0
        
        if getWhite(&white, alpha: &alpha) {
            return white
        }
        
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        
        getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        
        // Standard luminance calculation
        return (red * 0.299) + (green * 0.587) + (blue * 0.114)
    }
}
