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

class ViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegate {
    
    @IBOutlet weak var colorSlider: UISlider!
    @IBOutlet weak var collectionView: UICollectionView!
    
    lazy var progressView: UIProgressView = {
        let progress = UIProgressView(progressViewStyle: .default)
        progress.translatesAutoresizingMaskIntoConstraints = false
        return progress
    }()
    
    lazy var progressLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textAlignment = .center
        return label
    }()
    
    var totalProgress: Float = 0
    var totalSteps: Int = 0
    var allPhotoColors: [(asset: PHAsset, color: UIColor)] = []
    
    lazy var overlay: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    var allPhotos: PHFetchResult<PHAsset>!
    var filteredPhotos: [(asset: PHAsset, similarity: CGFloat)] = []
    var debounceTimer: Timer?
    
    let percentileThreshold: Double = 0.8
    let batchSize = 100 // Number of photos to process in each batch
    
    var averageColorCache: [String: UIColor] = [:]
    var processingQueue = DispatchQueue(label: "com.yourapp.photoProcessing", qos: .userInitiated, attributes: .concurrent)
    var isProcessing = false
    var processedAssets: Set<String> = []
    
    
    let userDefaults = UserDefaults.standard
    let cacheKey = "PhotoAnalysisCache"
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupPhotoLibraryAccess()
        loadCachedResults()
    }
    
    func setupUI() {
        setupColorSlider()
        setupCollectionView()
        
        view.addSubview(overlay)
        view.addSubview(progressView)
        view.addSubview(progressLabel)
        
        NSLayoutConstraint.activate([
            overlay.topAnchor.constraint(equalTo: view.topAnchor),
            overlay.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            overlay.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            overlay.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            progressView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            progressView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            progressView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            
            progressLabel.topAnchor.constraint(equalTo: progressView.bottomAnchor, constant: 10),
            progressLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor)
        ])
        
        // Initially hide the overlay and progress elements
        overlay.isHidden = true
        progressView.isHidden = true
        progressLabel.isHidden = true
    }
    
    func loadCachedResults() {
        if let cachedData = userDefaults.data(forKey: cacheKey),
           let cachedResults = try? JSONDecoder().decode([String: [String: CGFloat]].self, from: cachedData) {
            for (identifier, colorData) in cachedResults {
                if let red = colorData["red"],
                   let green = colorData["green"],
                   let blue = colorData["blue"] {
                    averageColorCache[identifier] = UIColor(red: red, green: green, blue: blue, alpha: 1.0)
                }
            }
        }
    }
    
    func saveCachedResults() {
        var cacheData: [String: [String: CGFloat]] = [:]
        for (identifier, color) in averageColorCache {
            var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
            color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
            cacheData[identifier] = ["red": red, "green": green, "blue": blue]
        }
        
        if let encodedData = try? JSONEncoder().encode(cacheData) {
            userDefaults.set(encodedData, forKey: cacheKey)
        }
    }
    
    func setupPhotoLibraryAccess() {
        PHPhotoLibrary.requestAuthorization { [weak self] status in
            guard let self = self else { return }
            if status == .authorized {
                DispatchQueue.main.async {
                    self.fetchPhotos()
                }
            } else {
                print("Photo library access denied")
                DispatchQueue.main.async {
                    self.showAccessDeniedAlert()
                }
            }
        }
    }
    
    func showAccessDeniedAlert() {
        let alert = UIAlertController(title: "Access Denied", message: "This app requires access to your photo library to function. Please grant access in Settings.", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Open Settings", style: .default) { _ in
            if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(settingsURL)
            }
        })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }
    
    func showNoPhotosAlert() {
        let alert = UIAlertController(title: "No Photos", message: "No photos were found in your library.", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let assets = filteredPhotos.map { $0.asset }
        let fullScreenVC = FullScreenPhotoViewController(orderedAssets: assets, initialIndex: indexPath.item)
        fullScreenVC.modalPresentationStyle = .fullScreen
        present(fullScreenVC, animated: true, completion: nil)
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
        return UIColor(hue: CGFloat(colorSlider.value), saturation: 1.0, brightness: 1.0, alpha:  1.0)
    }
    
    func fetchPhotos() {
        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        allPhotos = PHAsset.fetchAssets(with: .image, options: fetchOptions)
        
        if allPhotos.count == 0 {
            print("No photos found in the library")
            showNoPhotosAlert()
        } else {
            analyzeLibrary()
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
    
    func averageColor(for asset: PHAsset) -> UIColor? {
        if let cachedColor = averageColorCache[asset.localIdentifier] {
            return cachedColor
        }
        
        let manager = PHImageManager.default()
        let option = PHImageRequestOptions()
        option.isSynchronous = true
        option.deliveryMode = .fastFormat
        option.resizeMode = .fast
        option.isNetworkAccessAllowed = false
        
        var averageColor: UIColor?
        
        manager.requestImage(for: asset, targetSize: CGSize(width: 50, height: 50), contentMode: .aspectFit, options: option) { [weak self] image, info in
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
    
    func analyzeLibrary() {
        guard !isProcessing else { return }
        isProcessing = true
        
        // Show overlay and progress elements
        DispatchQueue.main.async {
            self.overlay.isHidden = false
            self.progressView.isHidden = false
            self.progressLabel.isHidden = false
            self.progressView.progress = 0
            self.progressLabel.text = "Analyzing photos: 0%"
        }
        
        let totalPhotos = allPhotos.count
        var processedPhotos = 0
        
        processingQueue.async { [weak self] in
            guard let self = self else { return }
            
            self.allPhotoColors.removeAll()
            
            for i in 0..<totalPhotos {
                autoreleasepool {
                    let asset = self.allPhotos.object(at: i)
                    
                    if let averageColor = self.averageColor(for: asset) {
                        self.allPhotoColors.append((asset: asset, color: averageColor))
                    }
                    
                    processedPhotos += 1
                    let progress = Float(processedPhotos) / Float(totalPhotos)
                    DispatchQueue.main.async {
                        self.progressView.progress = progress
                        self.progressLabel.text = "Analyzing photos: \(Int(progress * 100))%"
                    }
                }
            }
            
            DispatchQueue.main.async {
                self.isProcessing = false
                self.saveCachedResults()
                self.overlay.isHidden = true
                self.progressView.isHidden = true
                self.progressLabel.isHidden = true
                self.filterPhotosByColor(self.getSelectedColor())
            }
        }
    }
    
    func filterPhotosByColor(_ color: UIColor) {
        guard !isProcessing else { return }
        isProcessing = true
        
        print("Filtering photos for color: \(color)")
        
        filteredPhotos.removeAll()
        
        processingQueue.async { [weak self] in
            guard let self = self else { return }
            
            let filteredAndSorted = self.allPhotoColors.map { (asset: $0.asset, similarity: self.colorSimilarity($0.color, to: color)) }
                .sorted { $0.similarity < $1.similarity }
            
            let thresholdIndex = min(Int(Double(filteredAndSorted.count) * self.percentileThreshold), filteredAndSorted.count - 1)
            let newFilteredPhotos = Array(filteredAndSorted.prefix(thresholdIndex + 1))
            
            DispatchQueue.main.async {
                self.updateCollectionView(with: newFilteredPhotos)
                self.isProcessing = false
            }
        }
    }
    
    func updateProgress(step: Int) {
        let progress = Float(step) / Float(totalSteps)
        DispatchQueue.main.async {
            self.progressView.progress = progress
            self.progressLabel.text = "Processing: \(Int(progress * 100))%"
        }
    }
    
    func updateCollectionView(with newFilteredPhotos: [(asset: PHAsset, similarity: CGFloat)]) {
        // Remove any duplicates that might already be in filteredPhotos
        let newAssetIDs = Set(newFilteredPhotos.map { $0.asset.localIdentifier })
        self.filteredPhotos = self.filteredPhotos.filter { !newAssetIDs.contains($0.asset.localIdentifier) }
        
        // Append new filtered photos
        self.filteredPhotos.append(contentsOf: newFilteredPhotos)
        
        // Sort all filtered photos
        self.filteredPhotos.sort { $0.similarity < $1.similarity }
        
        // Keep only the top percentile
        let thresholdIndex = min(Int(Double(self.filteredPhotos.count) * self.percentileThreshold), self.filteredPhotos.count - 1)
        self.filteredPhotos = Array(self.filteredPhotos.prefix(thresholdIndex + 1))
        
        self.collectionView.reloadData()
        
        if !self.filteredPhotos.isEmpty && self.collectionView.contentOffset.y == 0 {
            self.collectionView.scrollToItem(at: IndexPath(item: 0, section: 0), at: .top, animated: false)
        }
    }
}

extension ViewController {
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
                
                // Optional display of the similarity score
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
