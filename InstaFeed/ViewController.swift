import UIKit
import Photos
import CoreImage

extension UIImage {
    var averageColor: UIColor? {
        guard let inputImage = CIImage(image: self) else { return nil }
        let extentVector = CIVector(x: inputImage.extent.origin.x, y: inputImage.extent.origin.y, z: inputImage.extent.size.width, w: inputImage.extent.size.height)

        guard let filter = CIFilter(name: "CIAreaAverage", parameters: [kCIInputImageKey: inputImage, kCIInputExtentKey: extentVector]) else { return nil }
        guard let outputImage = filter.outputImage else { return nil }

        var bitmap = [UInt8](repeating: 0, count: 4)
        let context = CIContext(options: [.workingColorSpace: kCFNull as Any])
        context.render(outputImage, toBitmap: &bitmap, rowBytes: 4, bounds: CGRect(x: 0, y: 0, width: 1, height: 1), format: .RGBA8, colorSpace: nil)

        return UIColor(red: CGFloat(bitmap[0]) / 255, green: CGFloat(bitmap[1]) / 255, blue: CGFloat(bitmap[2]) / 255, alpha: CGFloat(bitmap[3]) / 255)
    }
}

class ViewController: UIViewController {
    
    @IBOutlet weak var colorSlider: UISlider!
    @IBOutlet weak var collectionView: UICollectionView!
    
    var allPhotos: [PHAsset] = []
    var filteredPhotos: [(asset: PHAsset, similarity: CGFloat)] = []
    var debounceTimer: Timer?
    var lastFilteredPhotos: [(asset: PHAsset, similarity: CGFloat)] = []
    
    let percentileThreshold: Double = 0.3 //check how similar

    
    // Add a cache for average colors
    var averageColorCache: [String: UIColor] = [:]
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupPhotoLibraryAccess()
        setupColorSlider()
        setupCollectionView()
    }
    
    func setupPhotoLibraryAccess() {
        PHPhotoLibrary.requestAuthorization { status in
            if status == .authorized {
                DispatchQueue.main.async {
                    self.fetchPhotos()
                }
            } else {
                print("Photo library access denied")
                // Handle the case where the user denies access - !!TODO!! add a pop up
            }
        }
    }
    
    func setupCollectionView() {
        collectionView.dataSource = self
        collectionView.delegate = self
        
        collectionView.register(PhotoCell.self, forCellWithReuseIdentifier: "PhotoCell")
        
        let layout = UICollectionViewFlowLayout()
        layout.itemSize = CGSize(width: 100, height: 100)
        layout.minimumInteritemSpacing = 10
        layout.minimumLineSpacing = 10
        collectionView.collectionViewLayout = layout
    }
    
    func setupColorSlider() {
        guard let colorSlider = colorSlider else {
            print("Error: colorSlider is nil")
            return
        }

        // Create a gradient layer for the slider
        let gradientLayer = CAGradientLayer()
        gradientLayer.frame = colorSlider.bounds
        gradientLayer.colors = [
            UIColor.red.cgColor,
            UIColor.yellow.cgColor,
            UIColor.green.cgColor,
            UIColor.cyan.cgColor,
            UIColor.blue.cgColor,
            UIColor.magenta.cgColor,
            UIColor.red.cgColor
        ]
        gradientLayer.startPoint = CGPoint(x: 0.0, y: 0.5)
        gradientLayer.endPoint = CGPoint(x: 1.0, y: 0.5)

        // Create an image from the gradient layer
        UIGraphicsBeginImageContextWithOptions(gradientLayer.bounds.size, false, 0)
        if let context = UIGraphicsGetCurrentContext() {
            gradientLayer.render(in: context)
        }
        let gradientImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        // Set the gradient image as the slider's background
        colorSlider.setMinimumTrackImage(gradientImage, for: .normal)
        colorSlider.setMaximumTrackImage(gradientImage, for: .normal)

        // Configure slider
        colorSlider.minimumValue = 0.0
        colorSlider.maximumValue = 1.0
        colorSlider.value = 0.0
        colorSlider.addTarget(self, action: #selector(colorSliderChanged), for: .valueChanged)
    }
    
    @objc func colorSliderChanged() {
        let selectedColor = getSelectedColor()
        var hue: CGFloat = 0, saturation: CGFloat = 0, brightness: CGFloat = 0, alpha: CGFloat = 0
        selectedColor.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
        print("Selected color - Hue: \(hue), Saturation: \(saturation), Brightness: \(brightness)")
        
        debounceTimer?.invalidate()
        debounceTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: false) { [weak self] _ in
            self?.filterPhotosByColor(selectedColor)
        }
    }
 
    func getSelectedColor() -> UIColor {
        return UIColor(hue: CGFloat(colorSlider.value), saturation: 1.0, brightness: 1.0, alpha: 1.0)
    }

    func fetchPhotos() {
        let fetchOptions = PHFetchOptions()
        let fetchResult = PHAsset.fetchAssets(with: .image, options: fetchOptions)
        allPhotos = fetchResult.objects(at: IndexSet(integersIn: 0..<fetchResult.count))
        
        if allPhotos.isEmpty {
            print("No photos found in the library")
            // Handle the case where there are no photos
        } else {
            filterPhotosByColor(getSelectedColor())
        }
    }

    func colorSimilarity(_ color1: UIColor, to color2: UIColor) -> CGFloat {
        var hue1: CGFloat = 0, saturation1: CGFloat = 0, brightness1: CGFloat = 0, alpha1: CGFloat = 0
        var hue2: CGFloat = 0, saturation2: CGFloat = 0, brightness2: CGFloat = 0, alpha2: CGFloat = 0
        
        color1.getHue(&hue1, saturation: &saturation1, brightness: &brightness1, alpha: &alpha1)
        color2.getHue(&hue2, saturation: &saturation2, brightness: &brightness2, alpha: &alpha2)
        
        // Calculate the shortest distance between hues on the color wheel
        var hueDiff = abs(hue1 - hue2)
        hueDiff = min(hueDiff, 1 - hueDiff)
        
        // Calculate differences for saturation and brightness
        let satDiff = abs(saturation1 - saturation2)
        let brightDiff = abs(brightness1 - brightness2)
        
        // Weighted sum of differences (adjust weights as needed)
        let similarity = (hueDiff * 0.6) + (satDiff * 0.3) + (brightDiff * 0.1)
        
        return similarity
    }
    
    func filterPhotosByColor(_ color: UIColor) {
        print("Filtering photos for color: \(color)")
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            let allSimilarities = self.allPhotos.compactMap { asset -> (asset: PHAsset, similarity: CGFloat)? in
                guard let averageColor = self.averageColor(for: asset) else { return nil }
                let similarity = self.colorSimilarity(averageColor, to: color)
                return (asset: asset, similarity: similarity)
            }
            
            // Sort by similarity (lower is more similar)
            let sortedSimilarities = allSimilarities.sorted { $0.similarity < $1.similarity }
            
            // Take the top percentage of photos
            let thresholdIndex = min(Int(Double(sortedSimilarities.count) * self.percentileThreshold), sortedSimilarities.count - 1)
            let newFilteredPhotos = Array(sortedSimilarities.prefix(thresholdIndex + 1))
            
            print("Number of all photos: \(self.allPhotos.count)")
            print("Number of filtered photos: \(newFilteredPhotos.count)")
            
            if let mostSimilar = newFilteredPhotos.first, let leastSimilar = newFilteredPhotos.last {
                print("Most similar photo similarity: \(mostSimilar.similarity)")
                print("Least similar photo similarity: \(leastSimilar.similarity)")
            }

            DispatchQueue.main.async {
                self.updateCollectionView(with: newFilteredPhotos)
            }
        }
    }

    func averageColor(for asset: PHAsset) -> UIColor? {
        if let cachedColor = averageColorCache[asset.localIdentifier] {
            return cachedColor
        }

        let manager = PHImageManager.default()
        let option = PHImageRequestOptions()
        option.isSynchronous = true
        option.deliveryMode = .highQualityFormat
        option.resizeMode = .exact
        option.isNetworkAccessAllowed = true
        
        var averageColor: UIColor?
        
        manager.requestImage(for: asset, targetSize: CGSize(width: 100, height: 100), contentMode: .aspectFit, options: option) { [weak self] image, info in
            if let error = info?[PHImageErrorKey] as? Error {
                print("Image request failed with error: \(error)")
            }
            if let image = image, let color = image.averageColor {
                averageColor = color
                self?.averageColorCache[asset.localIdentifier] = color
            }
        }
        
        return averageColor
    }
    
    func updateCollectionView(with newFilteredPhotos: [(asset: PHAsset, similarity: CGFloat)]) {
        self.filteredPhotos = newFilteredPhotos
        self.collectionView.reloadData()
        
        if !self.filteredPhotos.isEmpty {
            self.collectionView.scrollToItem(at: IndexPath(item: 0, section: 0), at: .top, animated: true)
        }
    }
}

extension ViewController: UICollectionViewDataSource, UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return filteredPhotos.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "PhotoCell", for: indexPath) as? PhotoCell else {
            fatalError("Unable to dequeue PhotoCell")
        }
        
        let assetInfo = filteredPhotos[indexPath.item]
        
        let manager = PHImageManager.default()
        manager.requestImage(for: assetInfo.asset,
                             targetSize: CGSize(width: 100, height: 100),
                             contentMode: .aspectFill,
                             options: nil) { (image, _) in
            DispatchQueue.main.async {
                cell.imageView.image = image
                
                // Optionally, display the similarity score
                cell.similarityLabel.text = String(format: "%.2f", assetInfo.similarity)
            }
        }
        
        return cell
    }
}

//following is stolen from Paul Hudson - this have had me stumped for a while!

class PhotoCell: UICollectionViewCell {
    let imageView: UIImageView
    let similarityLabel: UILabel
    
    override init(frame: CGRect) {
        imageView = UIImageView(frame: .zero)
        similarityLabel = UILabel(frame: .zero)
        super.init(frame: frame)
        
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        contentView.addSubview(imageView)
        
        similarityLabel.textAlignment = .right
        similarityLabel.font = UIFont.systemFont(ofSize: 10)
        contentView.addSubview(similarityLabel)
        
        imageView.translatesAutoresizingMaskIntoConstraints = false
        similarityLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: contentView.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            
            similarityLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 2),
            similarityLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -2)
        ])
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
