import UIKit
import Photos
import CoreImage

// MARK: - UIImage Extension for Average Color
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

// MARK: - Point Struct for KMeans
struct Point: Equatable {
    let x: CGFloat
    let y: CGFloat
    let z: CGFloat
    
    init(_ x: CGFloat, _ y: CGFloat, _ z: CGFloat) {
        self.x = x
        self.y = y
        self.z = z
    }
    
    init(from color: UIColor) {
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        if color.getRed(&r, green: &g, blue: &b, alpha: &a) {
            x = r
            y = g
            z = b
        } else {
            x = 0
            y = 0
            z = 0
        }
    }
    
    func toUIColor() -> UIColor {
        return UIColor(red: x, green: y, blue: z, alpha: 1)
    }
    
    static func == (lhs: Point, rhs: Point) -> Bool {
        return lhs.x == rhs.x && lhs.y == rhs.y && lhs.z == rhs.z
    }
    
    static let zero = Point(0, 0, 0)
    
    static func +(lhs: Point, rhs: Point) -> Point {
        return Point(lhs.x + rhs.x, lhs.y + rhs.y, lhs.z + rhs.z)
    }
    
    static func /(lhs: Point, rhs: CGFloat) -> Point {
        return Point(lhs.x / rhs, lhs.y / rhs, lhs.z / rhs)
    }
    
    func distanceSquared(to p: Point) -> CGFloat {
        return (self.x - p.x) * (self.x - p.x)
            + (self.y - p.y) * (self.y - p.y)
            + (self.z - p.z) * (self.z - p.z)
    }
}

// MARK: - Cluster Class for KMeans
class Cluster {
    var points = [Point]()
    var center: Point
    
    init(center: Point) {
        self.center = center
    }
    
    func calculateCurrentCenter() -> Point {
        if points.isEmpty {
            return Point.zero
        }
        return points.reduce(Point.zero, +) / CGFloat(points.count)
    }
    
    func updateCenter() {
        if points.isEmpty {
            return
        }
        let currentCenter = calculateCurrentCenter()
        center = points.min(by: { $0.distanceSquared(to: currentCenter) < $1.distanceSquared(to: currentCenter) })!
    }
}

// MARK: - KMeans Class, SHAMELESSLY stolen from Nerius at https://dev.to/neriusv
class KMeans {
    private func findClosest(for p: Point, from clusters: [Cluster]) -> Cluster {
        return clusters.min(by: { $0.center.distanceSquared(to: p) < $1.center.distanceSquared(to: p) })!
    }
    
    func cluster(points: [Point], into k: Int) -> [Cluster] {
        guard points.count >= k else {
            return points.map { Cluster(center: $0) }
        }
        
        let clusters = (0..<k).map { _ in Cluster(center: points.randomElement()!) }
        
        for _ in 0..<100 { // Max 100 iterations
            clusters.forEach { $0.points.removeAll() }
            
            for p in points {
                let closest = findClosest(for: p, from: clusters)
                closest.points.append(p)
            }
            
            var converged = true
            clusters.forEach {
                let oldCenter = $0.center
                $0.updateCenter()
                if oldCenter.distanceSquared(to: $0.center) > 0.001 {
                    converged = false
                }
            }
            
            if converged {
                break
            }
        }
        
        return clusters
    }
}

// MARK: - ViewController
class ViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegate {
    
    @IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet weak var colorSlider: UISlider!
    @IBOutlet weak var sortingButton: UIButton!
    @IBOutlet weak var folderButton: UIButton!
    
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
    
    let percentileThreshold: Double = 0.3
    let batchSize = 100 // Number of photos to process in each batch
    
    var averageColorCache: [String: UIColor] = [:]
    var processingQueue = DispatchQueue(label: "com.yourapp.photoProcessing", qos: .userInitiated, attributes: .concurrent)
    var isProcessing = false
    var processedAssets: Set<String> = []
    
    let userDefaults = UserDefaults.standard
    let cacheKey = "PhotoAnalysisCache"
    
    let kMeans = KMeans()
    var dominantColors: [UIColor] = []
    
    enum SortingMethod {
        case color
        case shade
    }

    var currentSortingMethod: SortingMethod = .color
    
    var selectedCollection: PHAssetCollection?
    
    private let feedbackGenerator = UISelectionFeedbackGenerator()
    
    // MARK: - Lifecycle Methods
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupCollectionView()
        setupColorSlider()
        setupPhotoLibraryAccess()
        loadCachedResults()
        feedbackGenerator.prepare()
    }
    
    // MARK: - Setup Methods
    func setupUI() {
        view.backgroundColor = .black
        
        // Safely add and configure UI elements
        if let collectionView = collectionView {
            // Configure collectionView
        } else {
            print("Warning: collectionView is nil")
        }
        
        if let colorSlider = colorSlider {
            colorSlider.minimumValue = 0.0
            colorSlider.maximumValue = 1.0
            colorSlider.value = 0.0
            colorSlider.addTarget(self, action: #selector(colorSliderChanged), for: .valueChanged)
        } else {
            print("Warning: colorSlider is nil")
        }
        
        if sortingButton == nil {
            print("Warning: sortingButton is nil")
        }
        
        if folderButton == nil {
            print("Warning: folderButton is nil")
        }
        
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
    
    func setupCollectionView() {
        guard let collectionView = collectionView else {
            print("Error: collectionView is nil in setupCollectionView()")
            return
        }
        
        collectionView.dataSource = self
        collectionView.delegate = self
        
        let layout = UICollectionViewCompositionalLayout { _, _ in
            let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1/3),
                                                  heightDimension: .fractionalWidth(1/3))
            let item = NSCollectionLayoutItem(layoutSize: itemSize)
            item.contentInsets = NSDirectionalEdgeInsets(top: 1, leading: 1, bottom: 1, trailing: 1)
            
            let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0),
                                                   heightDimension: .fractionalWidth(1/3))
            let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])
            
            let section = NSCollectionLayoutSection(group: group)
            return section
        }
        
        collectionView.collectionViewLayout = layout
        collectionView.register(PhotoCell.self, forCellWithReuseIdentifier: "PhotoCell")
    }
    
    func setupColorSlider() {
        colorSlider.minimumValue = 0.0
        colorSlider.maximumValue = 1.0
        colorSlider.value = 0.0
        colorSlider.addTarget(self, action: #selector(colorSliderChanged), for: .valueChanged)
        colorSlider.addTarget(self, action: #selector(sliderTouchBegan), for: .touchDown)
        colorSlider.addTarget(self, action: #selector(sliderTouchEnded), for: [.touchUpInside, .touchUpOutside, .touchCancel])
    }
    
    @objc private func sliderTouchBegan() {
        feedbackGenerator.prepare()
    }
    
    @objc private func sliderTouchEnded() {
        // Optional: You can prepare the generator again for the next use
        feedbackGenerator.prepare()
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
    
    // MARK: - Photo Fetching Methods
    func fetchPhotos() {
        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        
        if let selectedCollection = selectedCollection {
            allPhotos = PHAsset.fetchAssets(in: selectedCollection, options: fetchOptions)
        } else {
            allPhotos = PHAsset.fetchAssets(with: .image, options: fetchOptions)
        }
        
        if allPhotos.count == 0 {
            print("No photos found in the selected folder")
            showNoPhotosAlert()
        } else {
            analyzeLibrary()
        }
    }
    
    // MARK: - Photo Analysis Methods
    func analyzeLibrary() {
        guard !isProcessing else { return }
        isProcessing = true

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.overlay.isHidden = false
            self.progressView.isHidden = false
            self.progressLabel.isHidden = false
            self.progressView.progress = 0
            self.progressLabel.text = "Analyzing photos: 0%"
        }
        
        let totalPhotos = allPhotos.count
        var processedPhotos = 0
        var allPoints: [Point] = []
        
        processingQueue.async { [weak self] in
            guard let self = self else { return }
            
            self.allPhotoColors.removeAll()
            
            for i in 0..<totalPhotos {
                autoreleasepool {
                    let asset = self.allPhotos.object(at: i)
                    
                    if let averageColor = self.averageColor(for: asset) {
                        let point = Point(from: averageColor)
                        allPoints.append(point)
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
            
            // Perform K-means clustering
            let clusters = self.kMeans.cluster(points: allPoints, into: 5)
            self.dominantColors = clusters.sorted(by: { $0.points.count > $1.points.count }).map { $0.center.toUIColor() }
            
            DispatchQueue.main.async {
                self.isProcessing = false
                self.saveCachedResults()
                self.overlay.isHidden = true
                self.progressView.isHidden = true
                self.progressLabel.isHidden = true
                self.updateColorSlider()
                self.filterPhotosByColor(self.dominantColors[0]) // Filter by the most dominant color
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
        option.deliveryMode = .highQualityFormat  // Changed from fastFormat
        option.resizeMode = .exact  // Changed from fast
        option.isNetworkAccessAllowed = false
        
        // Increased size for better color sampling
        let targetSize = CGSize(width: 120, height: 120)  // Increased from 50x50
        
        var averageColor: UIColor?
        
        manager.requestImage(for: asset,
                            targetSize: targetSize,
                            contentMode: .aspectFit,
                            options: option) { [weak self] image, info in
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
    
    func filterPhotosByColor(_ color: UIColor) {
        guard !isProcessing else { return }
        isProcessing = true
        
        print("Filtering photos for color: \(color)")
        
        filteredPhotos.removeAll()
        
        processingQueue.async { [weak self] in
            guard let self = self else { return }
            
            let targetPoint = Point(from: color)
            let filteredAndSorted = self.allPhotoColors.map { (asset: $0.asset, similarity: self.calculateSimilarity(targetPoint, Point(from: $0.color))) }
                .sorted { $0.similarity < $1.similarity }
            
            let thresholdIndex = min(Int(Double(filteredAndSorted.count) * self.percentileThreshold), filteredAndSorted.count - 1)
            let newFilteredPhotos = Array(filteredAndSorted.prefix(thresholdIndex + 1))
            
            DispatchQueue.main.async {
                self.updateCollectionView(with: newFilteredPhotos)
                self.isProcessing = false
            }
        }
    }
    
    func calculateSimilarity(_ p1: Point, _ p2: Point) -> CGFloat {
        switch currentSortingMethod {
        case .color:
            return colorSimilarity(p1, p2)
        case .shade:
            return shadeSimilarity(p1, p2)
        }
    }
    
    // MARK: - UI Update Methods
    func updateColorSlider() {
        let gradientLayer = CAGradientLayer()
        gradientLayer.frame = colorSlider.bounds
        
        var colors: [CGColor] = []
        
        switch currentSortingMethod {
        case .color:
            // Create a color array representing the full spectrum
            let colorCount = 12 // Number of color stops
            for i in 0..<colorCount {
                let hue = CGFloat(i) / CGFloat(colorCount)
                let color = UIColor(hue: hue, saturation: 1.0, brightness: 1.0, alpha: 1.0)
                colors.append(color.cgColor)
            }
            colors.append(UIColor(hue: 0, saturation: 1.0, brightness: 1.0, alpha: 1.0).cgColor) // Add red again to complete the circle
        case .shade:
            // Create a grayscale gradient from black to white
            colors = [
                UIColor.black.cgColor,
                UIColor.white.cgColor
            ]
        }
        
        gradientLayer.colors = colors
        gradientLayer.startPoint = CGPoint(x: 0.0, y: 0.5)
        gradientLayer.endPoint = CGPoint(x: 1.0, y: 0.5)
        
        UIGraphicsBeginImageContextWithOptions(gradientLayer.bounds.size, false, 0)
        if let context = UIGraphicsGetCurrentContext() {
            gradientLayer.render(in: context)
        }
        let gradientImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        colorSlider.setMinimumTrackImage(gradientImage, for: .normal)
        colorSlider.setMaximumTrackImage(gradientImage, for: .normal)
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
        
        self.scrollCollectionViewToTop()
        
        if !self.filteredPhotos.isEmpty && self.collectionView.contentOffset.y == 0 {
            self.collectionView.scrollToItem(at: IndexPath(item: 0, section: 0), at: .top, animated: false)
        }
    }

    private func changeSortingMethod(to method: SortingMethod) {
        currentSortingMethod = method
        updateColorSlider()
        filterPhotosByColor(getSelectedColor())
    }
    
    // MARK: - User Interaction Methods
        
    @IBAction func sortingButtonTapped(_ sender: Any) {
        let alert = UIAlertController(title: "Select Sorting Method", message: nil, preferredStyle: .actionSheet)
        
        alert.addAction(UIAlertAction(title: "Sort by Color", style: .default) { [weak self] _ in
            self?.changeSortingMethod(to: .color)
        })
        
        alert.addAction(UIAlertAction(title: "Sort by Shade", style: .default) { [weak self] _ in
            self?.changeSortingMethod(to: .shade)
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        if let popoverController = alert.popoverPresentationController {
            popoverController.sourceView = sortingButton
            popoverController.sourceRect = sortingButton.bounds
        }
        
        present(alert, animated: true)
    }
    
    @IBAction func folderButtonTapped(_ sender: Any) {
        let alert = UIAlertController(title: "Select Folder", message: nil, preferredStyle: .actionSheet)
        
        alert.addAction(UIAlertAction(title: "All Photos", style: .default) { [weak self] _ in
            self?.selectAllPhotos()
        })
        
        alert.addAction(UIAlertAction(title: "Select Album", style: .default) { [weak self] _ in
            self?.showAlbumPicker()
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        if let popoverController = alert.popoverPresentationController {
            popoverController.sourceView = folderButton
            popoverController.sourceRect = folderButton.bounds
        }
        
        present(alert, animated: true)
    }
    
    func getSelectedColor() -> UIColor {
        switch currentSortingMethod {
        case .color:
            let hue = CGFloat(colorSlider.value)
            return UIColor(hue: hue, saturation: 1.0, brightness: 1.0, alpha: 1.0)
        case .shade:
            let brightness = CGFloat(colorSlider.value)
            return UIColor(white: brightness, alpha: 1.0)
        }
    }
    
    @objc func colorSliderChanged() {
        let selectedColor = getSelectedColor()
        
        feedbackGenerator.selectionChanged()
        
        // Cancel any existing preview timer
        previewTimer?.invalidate()
        
        // Show preview immediately with low-quality images
        showPreview(for: selectedColor)
        
        // Debounce the full-quality update
        debounceTimer?.invalidate()
        debounceTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: false) { [weak self] _ in
            self?.filterPhotosByColor(selectedColor)
        }
    }
    
    private var previewTimer: Timer?
    
    private func showPreview(for color: UIColor) {
        guard !isProcessing else { return }
        
        let targetPoint = Point(from: color)
        let quickFilteredPhotos = allPhotoColors.map { (asset: $0.asset, similarity: calculateSimilarity(targetPoint, Point(from: $0.color))) }
            .sorted { $0.similarity < $1.similarity }
            .prefix(Int(Double(allPhotoColors.count) * percentileThreshold))
        
        // Update UI with low-quality previews
        DispatchQueue.main.async {
            self.filteredPhotos = Array(quickFilteredPhotos)
            self.collectionView.reloadData()
        }
    }
    
    private func scrollCollectionViewToTop() {
        DispatchQueue.main.async {
            if self.filteredPhotos.count > 0 {
                let indexPath = IndexPath(item: 0, section: 0)
                self.collectionView?.scrollToItem(at: indexPath, at: .top, animated: true)
            }
        }
    }
    
    func selectAllPhotos() {
        selectedCollection = nil
//        selectedFolderLabel.text = "All Photos"
        fetchPhotos()
    }
    
    func showAlbumPicker() {
        let albumPicker = UIAlertController(title: "Select Album", message: nil, preferredStyle: .actionSheet)
        
        let userAlbums = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .any, options: nil)
        userAlbums.enumerateObjects { (collection, _, _) in
            albumPicker.addAction(UIAlertAction(title: collection.localizedTitle ?? "Untitled Album", style: .default) { [weak self] _ in
                self?.selectedCollection = collection
//                self?.selectedFolderLabel.text = collection.localizedTitle ?? "Untitled Album"
                self?.fetchPhotos()
            })
        }
        
        albumPicker.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        if let popoverController = albumPicker.popoverPresentationController {
            popoverController.sourceView = folderButton
            popoverController.sourceRect = folderButton.bounds
        }
        
        present(albumPicker, animated: true)
    }
    
    // MARK: - Data Management Methods
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
    
    // MARK: - Helper Methods
  
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
}

// MARK: - UICollectionViewDataSource, UICollectionViewDelegate - this entire part is utterly confusing and is written by my one and only Claude
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
        let targetSize = CGSize(width: collectionView.bounds.width / 3, height: collectionView.bounds.width / 3)
        manager.requestImage(for: assetInfo.asset,
                             targetSize: targetSize,
                             contentMode: .aspectFill,
                             options: nil) { (image, _) in
            DispatchQueue.main.async {
                cell.imageView.image = image
                cell.similarityLabel.text = String(format: "%.2f", assetInfo.similarity)
            }
        }
        
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let assets = filteredPhotos.map { $0.asset }
        
        // Create a dictionary of asset colors
        let assetColors = Dictionary(uniqueKeysWithValues: allPhotoColors.map { ($0.asset.localIdentifier, $0.color) })

        let fullScreenVC = FullScreenPhotoViewController(orderedAssets: assets, initialIndex: indexPath.item, assetColors: assetColors)
        fullScreenVC.modalPresentationStyle = .fullScreen
        present(fullScreenVC, animated: true, completion: nil)
    }
}

// MARK: - ViewController Extension for Color Calculations
extension ViewController {
    private func colorSimilarity(_ p1: Point, _ p2: Point) -> CGFloat {
        var h1: CGFloat = 0, s1: CGFloat = 0, b1: CGFloat = 0
        var h2: CGFloat = 0, s2: CGFloat = 0, b2: CGFloat = 0
        
        let color1 = UIColor(red: p1.x, green: p1.y, blue: p1.z, alpha: 1)
        let color2 = UIColor(red: p2.x, green: p2.y, blue: p2.z, alpha: 1)
        
        guard color1.getHue(&h1, saturation: &s1, brightness: &b1, alpha: nil),
              color2.getHue(&h2, saturation: &s2, brightness: &b2, alpha: nil) else {
            return 1.0
        }
        
        // Handle very dark images (nearly black)
        if b1 < 0.1 || b2 < 0.1 {
            return 1.0  // Exclude very dark images from color matching
        }
        
        // Handle very low saturation (grayscale-ish) images
        if s1 < 0.15 || s2 < 0.15 {
            return 1.0  // Exclude very desaturated images from color matching
        }
        
        // Calculate hue difference with stricter boundaries
        var hueDiff = abs(h1 - h2)
        if hueDiff > 0.5 {
            hueDiff = 1.0 - hueDiff
        }
        
        // Apply a threshold to hue difference
        // This makes the color boundaries more distinct
        if hueDiff > 0.15 {  // Reduced from typical 0.5 to be more strict
            return 1.0
        }
        
        // Calculate saturation and brightness differences
        let saturationDiff = abs(s1 - s2)
        let brightnessDiff = abs(b1 - b2)
        
        // Weight the components with higher emphasis on hue matching
        let similarity = (hueDiff * 0.8) + (saturationDiff * 0.15) + (brightnessDiff * 0.05)
        
        return similarity
    }

    private func shadeSimilarity(_ p1: Point, _ p2: Point) -> CGFloat {
        // For grayscale comparison, use perceived brightness
        let brightness1 = 0.299 * p1.x + 0.587 * p1.y + 0.114 * p1.z
        let brightness2 = 0.299 * p2.x + 0.587 * p2.y + 0.114 * p2.z
        return abs(brightness1 - brightness2)
    }

    private func rgbToLab(r: CGFloat, g: CGFloat, b: CGFloat) -> (L: CGFloat, a: CGFloat, b: CGFloat) {
        // Convert RGB to XYZ
        func toLinear(_ c: CGFloat) -> CGFloat {
            return c > 0.04045 ? pow((c + 0.055) / 1.055, 2.4) : c / 12.92
        }
        let rLinear = toLinear(r)
        let gLinear = toLinear(g)
        let bLinear = toLinear(b)
        
        let x = rLinear * 0.4124564 + gLinear * 0.3575761 + bLinear * 0.1804375
        let y = rLinear * 0.2126729 + gLinear * 0.7151522 + bLinear * 0.0721750
        let z = rLinear * 0.0193339 + gLinear * 0.1191920 + bLinear * 0.9503041
        
        // Convert XYZ to Lab
        func f(_ t: CGFloat) -> CGFloat {
            return t > pow(6.0 / 29.0, 3) ? pow(t, 1.0 / 3.0) : (1.0 / 3.0) * pow(29.0 / 6.0, 2) * t + 4.0 / 29.0
        }
        let xn: CGFloat = 0.95047
        let yn: CGFloat = 1.00000
        let zn: CGFloat = 1.08883
        
        let L = 116 * f(y / yn) - 16
        let a = 500 * (f(x / xn) - f(y / yn))
        let b = 200 * (f(y / yn) - f(z / zn))
        
        return (L, a, b)
    }

    private func deltaE2000(lab1: (L: CGFloat, a: CGFloat, b: CGFloat), lab2: (L: CGFloat, a: CGFloat, b: CGFloat)) -> CGFloat {
        let kL: CGFloat = 1
        let kC: CGFloat = 1
        let kH: CGFloat = 1
        
        let deltaL = lab2.L - lab1.L
        let L_ = (lab1.L + lab2.L) / 2
        let C1 = sqrt(lab1.a * lab1.a + lab1.b * lab1.b)
        let C2 = sqrt(lab2.a * lab2.a + lab2.b * lab2.b)
        let C_ = (C1 + C2) / 2
        
        let a1_ = lab1.a + lab1.a / 2 * (1 - sqrt(pow(C_, 7) / (pow(C_, 7) + pow(25, 7))))
        let a2_ = lab2.a + lab2.a / 2 * (1 - sqrt(pow(C_, 7) / (pow(C_, 7) + pow(25, 7))))
        
        let C1_ = sqrt(a1_ * a1_ + lab1.b * lab1.b)
        let C2_ = sqrt(a2_ * a2_ + lab2.b * lab2.b)
        let C__ = (C1_ + C2_) / 2
        
        let h1_ = (atan2(lab1.b, a1_) + .pi * 2).truncatingRemainder(dividingBy: .pi * 2)
        let h2_ = (atan2(lab2.b, a2_) + .pi * 2).truncatingRemainder(dividingBy: .pi * 2)
        
        var H_ = (h1_ + h2_) / 2
        if abs(h1_ - h2_) > .pi {
            H_ += .pi
        }
        
        let T = 1 - 0.17 * cos(H_ - .pi / 6) + 0.24 * cos(2 * H_) + 0.32 * cos(3 * H_ + .pi / 30) - 0.20 * cos(4 * H_ - .pi / 5)
        
        let deltaH_ = 2 * sqrt(C1_ * C2_) * sin((h2_ - h1_) / 2)
        
        let SL = 1 + (0.015 * pow(L_ - 50, 2)) / sqrt(20 + pow(L_ - 50, 2))
        let SC = 1 + 0.045 * C__
        let SH = 1 + 0.015 * C__ * T
        
        let RT = -2 * sqrt(pow(C__, 7) / (pow(C__, 7) + pow(25, 7))) * sin(2 * 60 * .pi / 180 * exp(-pow((H_ * 180 / .pi - 275) / 25, 2)))
        
        let deltaE = sqrt(
            pow(deltaL / (kL * SL), 2) +
            pow((C2_ - C1_) / (kC * SC), 2) +
            pow(deltaH_ / (kH * SH), 2) +
            RT * (C2_ - C1_) / (kC * SC) * deltaH_ / (kH * SH)
        )
        
        return deltaE
    }
}

// MARK: - PhotoCell
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
