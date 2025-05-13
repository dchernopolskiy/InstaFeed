import UIKit
import Photos

// Updated implementation with integration of components
class MainViewController: UIViewController {
    
    // MARK: - UI Elements
    private var collectionView: UICollectionView!
    private var floatingButtons: FloatingButtonsView!
    private var colorWheelView: ColorWheelView!
    private var loadingIndicator: UIActivityIndicatorView!
    private var progressView: UIProgressView!
    
    // MARK: - Properties
    private var photoAssets: [PhotoAsset] = []
    private var filteredPhotoAssets: [PhotoAsset] = []
    private var selectedColor: UIColor = UIColor(hue: 0.7, saturation: 1.0, brightness: 1.0, alpha: 1.0) // Purple by default
    private var currentSortingMethod: SimilarityMethod = .color
    private let feedbackGenerator = UISelectionFeedbackGenerator()
    var filteredPhotos: [AssetViewModel] = []
    
    private var isFirstLaunch: Bool {
        return !UserDefaults.standard.bool(forKey: "HasCompletedInitialAnalysis")
    }
    
    private var lastAnalysisDate: Date? {
        return UserDefaults.standard.object(forKey: "LastAnalysisDate") as? Date
    }
    
    private var progressLabel: UILabel!
    
    // MARK: - Lifecycle Methods
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Load cached colors
        CacheManager.shared.preloadFromDisk()
        
        setupUI()
        requestPhotoAccess()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Save color cache when view disappears
        CacheManager.shared.saveColorsToDisk()
    }
    
    // MARK: - Setup Methods
    private func setupUI() {
        view.backgroundColor = .black
        
        setupNavigationBar()
        setupCollectionView()
        setupFloatingButtons()
        setupColorWheel()
        setupLoading()
    }
    
    private func setupNavigationBar() {
        navigationController?.navigationBar.barStyle = .black
        navigationController?.navigationBar.tintColor = .white
        navigationController?.navigationBar.titleTextAttributes = [NSAttributedString.Key.foregroundColor: UIColor.white]
        navigationItem.title = "InstaFeed"
        
        // Add right bar items
        let gridButton = UIBarButtonItem(image: UIImage(systemName: "square.grid.3x3"), style: .plain, target: self, action: #selector(gridButtonTapped))
        let instaButton = UIBarButtonItem(image: UIImage(systemName: "camera"), style: .plain, target: self, action: #selector(instaButtonTapped))
        navigationItem.rightBarButtonItems = [instaButton, gridButton]
    }
    
    private func setupCollectionView() {
        // Create layout
        let layout = UICollectionViewCompositionalLayout { _, _ in
            let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1/3), heightDimension: .fractionalWidth(1/3))
            let item = NSCollectionLayoutItem(layoutSize: itemSize)
            item.contentInsets = NSDirectionalEdgeInsets(top: 0.5, leading: 0.5, bottom: 0.5, trailing: 0.5)
            
            let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .fractionalWidth(1/3))
            let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])
            
            let section = NSCollectionLayoutSection(group: group)
            return section
        }
        
        // Create collection view
        collectionView = UICollectionView(frame: view.bounds, collectionViewLayout: layout)
        collectionView.backgroundColor = .black
        collectionView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        collectionView.register(PhotoCell.self, forCellWithReuseIdentifier: "PhotoCell")
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 120, right: 0) // Bottom padding for buttons
        view.addSubview(collectionView)
    }
    
    private func setupFloatingButtons() {
        // Create floating buttons
        floatingButtons = FloatingButtonsView(frame: .zero)
        floatingButtons.delegate = self
        floatingButtons.setColorButtonColor(selectedColor)
        view.addSubview(floatingButtons)
        
        // Setup constraints
        floatingButtons.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            floatingButtons.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            floatingButtons.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            floatingButtons.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),
            floatingButtons.heightAnchor.constraint(equalToConstant: 64)
        ])
    }
    
    private func setupColorWheel() {
        // Create color wheel view (initially hidden)
        colorWheelView = ColorWheelView(frame: CGRect(x: 0, y: 0, width: 250, height: 250))
        colorWheelView.delegate = self
        colorWheelView.alpha = 0
        view.addSubview(colorWheelView)
    }
    
    private func setupLoading() {
        // Create loading indicator
        loadingIndicator = UIActivityIndicatorView(style: .large)
        loadingIndicator.color = .white
        loadingIndicator.hidesWhenStopped = true
        view.addSubview(loadingIndicator)
        
        // Create progress view
        progressView = UIProgressView(progressViewStyle: .default)
        progressView.trackTintColor = UIColor.gray.withAlphaComponent(0.3)
        progressView.progressTintColor = .white
        progressView.isHidden = true
        view.addSubview(progressView)
        
        // Create progress label
        progressLabel = UILabel()
        progressLabel.textColor = .white
        progressLabel.textAlignment = .center
        progressLabel.font = UIFont.systemFont(ofSize: 14)
        progressLabel.numberOfLines = 0
        progressLabel.isHidden = true
        view.addSubview(progressLabel)
        
        // Layout
        loadingIndicator.translatesAutoresizingMaskIntoConstraints = false
        progressView.translatesAutoresizingMaskIntoConstraints = false
        progressLabel.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            loadingIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            
            progressView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            progressView.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: 40),
            progressView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 40),
            progressView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -40),
            
            progressLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            progressLabel.topAnchor.constraint(equalTo: progressView.bottomAnchor, constant: 20),
            progressLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 40),
            progressLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -40)
        ])
    }
    
    // MARK: - Photo Access Methods
    private func requestPhotoAccess() {
        PhotoLibraryManager.shared.delegate = self
        PhotoLibraryManager.shared.requestAuthorization()
    }
    
    private func analyzePhotos() {
        guard let allPhotos = PhotoLibraryManager.shared.allPhotos else { return }
        
        if isFirstLaunch {
            analyzeFullLibrary()
        } else {
            analyzeNewPhotos()
        }
    }

    private func analyzeFullLibrary() {
        guard let allPhotos = PhotoLibraryManager.shared.allPhotos else { return }
        
        let totalCount = allPhotos.count
        print("📁 First launch - analyzing entire photo library (\(totalCount) photos)")
        
        // Show loading UI with message and count
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.loadingIndicator.startAnimating()
            self.progressView.isHidden = false
            self.progressView.progress = 0
            self.progressLabel.isHidden = false
            self.progressLabel.text = "Analyzing your photo library...\n0/\(totalCount) photos\nDon't worry, this only takes long the first time!"
        }
        
        // Create photo assets for entire library
        photoAssets.removeAll()
        for i in 0..<allPhotos.count {
            let asset = allPhotos.object(at: i)
            photoAssets.append(PhotoAsset(asset: asset))
        }
        
        // Analyze all photos
        analyzePhotosBatch(photoAssets) { [weak self] progress in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                self.progressView.progress = progress
                let processedCount = Int(progress * Float(totalCount))
                self.progressLabel.text = "Analyzing your photo library...\n\(processedCount)/\(totalCount) photos\nDon't worry, this only takes long the first time!"
            }
        } completion: { [weak self] in
            guard let self = self else { return }
            
            // Mark first launch as complete
            UserDefaults.standard.set(true, forKey: "HasCompletedInitialAnalysis")
            UserDefaults.standard.set(Date(), forKey: "LastAnalysisDate")
            
            // Save cache on background queue
            DispatchQueue.global(qos: .background).async {
                CacheManager.shared.saveColorsToDisk()
            }
            
            DispatchQueue.main.async {
                self.loadingIndicator.stopAnimating()
                self.progressView.isHidden = true
                self.progressLabel.isHidden = true
                self.filterAndSortPhotoAssets()
                self.collectionView.reloadData()
            }
        }
    }

    private func analyzeNewPhotos() {
        guard let allPhotos = PhotoLibraryManager.shared.allPhotos,
              let lastAnalysis = lastAnalysisDate else {
            // If no last analysis date, do full analysis
            analyzeFullLibrary()
            return
        }
        
        print("📁 Checking for new photos since \(lastAnalysis)")
        
        // Find photos added since last analysis
        let fetchOptions = PHFetchOptions()
        fetchOptions.predicate = NSPredicate(format: "creationDate > %@", lastAnalysis as NSDate)
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        
        let newPhotos = PHAsset.fetchAssets(with: .image, options: fetchOptions)
        
        if newPhotos.count == 0 {
            print("📁 No new photos to analyze")
            loadExistingData()
            return
        }
        
        print("📁 Found \(newPhotos.count) new photos to analyze")
        
        // Show subtle loading indicator
        loadingIndicator.startAnimating()
        progressLabel.isHidden = false
        progressLabel.text = "Updating with \(newPhotos.count) new photos..."
        
        // Analyze only new photos
        var newPhotoAssets: [PhotoAsset] = []
        for i in 0..<newPhotos.count {
            let asset = newPhotos.object(at: i)
            newPhotoAssets.append(PhotoAsset(asset: asset))
        }
        
        analyzePhotosBatch(newPhotoAssets) { progress in
            // Optionally update UI
        } completion: { [weak self] in
            guard let self = self else { return }
            
            // Add new photos to our collection
            self.photoAssets.append(contentsOf: newPhotoAssets)
            
            // Update last analysis date
            UserDefaults.standard.set(Date(), forKey: "LastAnalysisDate")
            
            // Save cache
            CacheManager.shared.saveColorsToDisk()
            
            DispatchQueue.main.async {
                self.loadingIndicator.stopAnimating()
                self.progressLabel.isHidden = true
                self.loadExistingData()
            }
        }
    }

    private func loadExistingData() {
        guard let allPhotos = PhotoLibraryManager.shared.allPhotos else { return }
        
        // Load from cache
        CacheManager.shared.preloadFromDisk()
        let cachedColors = CacheManager.shared.getCachedColors()
        
        print("📁 Loading from cache: \(cachedColors.count) colors cached")
        
        // Create photo assets from cached data
        photoAssets.removeAll()
        for i in 0..<allPhotos.count {
            let asset = allPhotos.object(at: i)
            let photoAsset = PhotoAsset(asset: asset)
            
            // Load cached color if available
            if let cachedColor = cachedColors[asset.localIdentifier] {
                photoAsset.averageColor = cachedColor
                photoAsset.isAnalyzed = true
            }
            
            photoAssets.append(photoAsset)
        }
        
        filterAndSortPhotoAssets()
        collectionView.reloadData()
    }

    private func analyzePhotosBatch(_ photos: [PhotoAsset], progress: @escaping (Float) -> Void, completion: @escaping () -> Void) {
        let totalCount = photos.count
        var processedCount = 0
        let batchSize = 50
        
        // Move all analysis to background queue to prevent blocking UI
        DispatchQueue.global(qos: .userInitiated).async {
            let group = DispatchGroup()
            
            for i in stride(from: 0, to: photos.count, by: batchSize) {
                let endIndex = min(i + batchSize, photos.count)
                let batch = Array(photos[i..<endIndex])
                
                for photoAsset in batch {
                    group.enter()
                    photoAsset.analyzeColor { success in
                        if success, let color = photoAsset.averageColor {
                            CacheManager.shared.setColor(color, for: photoAsset.identifier)
                        } else {
                            print("⚠️ Failed to analyze photo: \(photoAsset.identifier)")
                        }
                        
                        processedCount += 1
                        
                        // Update progress on main thread
                        DispatchQueue.main.async {
                            progress(Float(processedCount) / Float(totalCount))
                        }
                        
                        group.leave()
                    }
                }
                
                // Wait for batch to complete before starting next
                group.wait()
            }
            
            // Call completion on main thread
            group.notify(queue: .main) {
                completion()
            }
        }
    }
    
    private func filterAndSortPhotoAssets() {
        // Start with a fresh array
        filteredPhotoAssets.removeAll()
        
        // Add filtered assets
        filteredPhotoAssets = photoAssets.filter { $0.averageColor != nil }
        
        // Calculate similarity
        for asset in filteredPhotoAssets {
            if let color = asset.averageColor {
                asset.similarityValue = ColorAnalysis.shared.calculateSimilarity(
                    between: selectedColor,
                    and: color,
                    method: currentSortingMethod
                )
            }
        }
        
        // Sort by similarity
        filteredPhotoAssets.sort { $0.similarityValue < $1.similarityValue }
    }
    
    private func updatePhotosWithColor(_ color: UIColor) {
        selectedColor = color
        floatingButtons.setColorButtonColor(color)
        
        loadingIndicator.startAnimating()
        
        // Since all photos are already analyzed, just update similarity
        for asset in filteredPhotoAssets {
            if let assetColor = asset.averageColor {
                asset.similarityValue = ColorAnalysis.shared.calculateSimilarity(
                    between: color,
                    and: assetColor,
                    method: currentSortingMethod
                )
            }
        }
        
        // Sort by similarity
        filteredPhotoAssets.sort { $0.similarityValue < $1.similarityValue }
        
        DispatchQueue.main.async {
            self.loadingIndicator.stopAnimating()
            self.collectionView.reloadData()
            
            if !self.filteredPhotoAssets.isEmpty {
                self.collectionView.scrollToItem(at: IndexPath(item: 0, section: 0), at: .top, animated: true)
            }
        }
    }
    
    // MARK: - User Interaction Methods
    @objc private func gridButtonTapped() {
        // Check if we have filtered photos to preview
        if filteredPhotoAssets.isEmpty {
            let alert = UIAlertController(title: "No Photos", message: "There are no photos to preview.", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
            return
        }
        
        // Convert filtered photo assets to PHAsset array for preview
        let assets = filteredPhotoAssets.map { $0.asset }
        
        // Create dictionary of asset colors
        var assetColors: [String: UIColor] = [:]
        for photoAsset in filteredPhotoAssets {
            if let color = photoAsset.averageColor {
                assetColors[photoAsset.identifier] = color
            }
        }
        
        let previewVC = PreviewViewController(orderedAssets: assets, assetColors: assetColors)
        previewVC.modalPresentationStyle = .fullScreen
        present(previewVC, animated: true)
    }
    
    @objc private func instaButtonTapped() {
        let alert = UIAlertController(title: "Instagram", message: "Would you like to open Instagram?", preferredStyle: .alert)
        
        alert.addAction(UIAlertAction(title: "Open Instagram", style: .default) { _ in
            if let instagramURL = URL(string: "instagram://") {
                if UIApplication.shared.canOpenURL(instagramURL) {
                    UIApplication.shared.open(instagramURL)
                } else {
                    // Instagram not installed
                    let appStoreURL = URL(string: "https://apps.apple.com/app/instagram/id389801252")!
                    UIApplication.shared.open(appStoreURL)
                }
            }
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }
    
    @objc private func folderButtonTapped() {
        let albumPicker = AlbumPickerViewController()
        albumPicker.delegate = self
        
        let navController = UINavigationController(rootViewController: albumPicker)
        navController.navigationBar.barStyle = .black
        navController.navigationBar.tintColor = .white
        navController.modalPresentationStyle = .fullScreen
        
        present(navController, animated: true)
    }
    
    private func showAlbumPicker() {
        PhotoLibraryManager.shared.fetchAlbums { [weak self] albums in
            guard let self = self else { return }
            
            let albumPicker = UIAlertController(title: "Select Album", message: nil, preferredStyle: .actionSheet)
            
            // Add "All Photos" option
            albumPicker.addAction(UIAlertAction(title: "All Photos", style: .default) { [weak self] _ in
                self?.selectAlbum(nil)
            })
            
            // Add each album
            for album in albums {
                // Skip empty albums
                let assetCount = PHAsset.fetchAssets(in: album, options: nil).count
                if assetCount == 0 { continue }
                
                albumPicker.addAction(UIAlertAction(title: "\(album.localizedTitle ?? "Untitled") (\(assetCount))", style: .default) { [weak self] _ in
                    self?.selectAlbum(album)
                })
            }
            
            albumPicker.addAction(UIAlertAction(title: "Cancel", style: .cancel))
            
            if let popoverController = albumPicker.popoverPresentationController {
                popoverController.sourceView = self.floatingButtons.folderButton
                popoverController.sourceRect = self.floatingButtons.folderButton.bounds
            }
            
            self.present(albumPicker, animated: true)
        }
    }
    
    private func selectAlbum(_ album: PHAssetCollection?) {
        PhotoLibraryManager.shared.selectCollection(album)
        // Library manager will call delegate methods to update the UI
    }
    
    private func changeSortingMethod(to method: SimilarityMethod) {
        currentSortingMethod = method
        updatePhotosWithColor(selectedColor)
    }
    
    // MARK: - Helper Methods
    private func showAccessDeniedAlert() {
        let alert = UIAlertController(
            title: "Photo Access Required",
            message: "InstaFeed needs access to your photos to organize them by color. Please grant access in Settings.",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Open Settings", style: .default) { _ in
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url)
            }
        })
        
        present(alert, animated: true)
    }
}

// MARK: - FloatingButtonsDelegate
extension MainViewController: FloatingButtonsDelegate {
    func floatingButtonsDidTapSettings(_ view: FloatingButtonsView) {
        let alert = UIAlertController(title: "Select Sorting Method", message: nil, preferredStyle: .actionSheet)
        
        alert.addAction(UIAlertAction(title: "Sort by Color", style: .default) { [weak self] _ in
            self?.changeSortingMethod(to: .color)
        })
        
        alert.addAction(UIAlertAction(title: "Sort by Shade", style: .default) { [weak self] _ in
            self?.changeSortingMethod(to: .shade)
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        if let popoverController = alert.popoverPresentationController {
            popoverController.sourceView = view.settingsButton
            popoverController.sourceRect = view.settingsButton.bounds
        }
        
        present(alert, animated: true)
    }
    
    func floatingButtonsDidLongPressColor(_ view: FloatingButtonsView, at point: CGPoint, with gestureRecognizer: UILongPressGestureRecognizer) {
        switch gestureRecognizer.state {
        case .began:
            // Position wheel above the button
            let buttonCenter = view.colorButton.center
            let viewPoint = view.convert(buttonCenter, to: self.view)
            colorWheelView.center = CGPoint(x: viewPoint.x, y: viewPoint.y - 150)
            colorWheelView.show()
            
            // Log for debugging
            print("🔄 Color wheel shown at \(colorWheelView.center)")
            
            // Prepare haptic feedback
            feedbackGenerator.prepare()
            feedbackGenerator.selectionChanged()
            
        case .changed:
            // Convert touch location to color wheel coordinates
            let locationInWheel = gestureRecognizer.location(in: colorWheelView)
            
            // Log for debugging
            print("🔄 Touch point in wheel: \(locationInWheel)")
            
            // Update selector and get color
            if let color = colorWheelView.updateSelector(at: locationInWheel) {
                // Log selected color
                var hue: CGFloat = 0
                var saturation: CGFloat = 0
                var brightness: CGFloat = 0
                var alpha: CGFloat = 0
                color.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
                print("🔄 Selected color - hue: \(hue), sat: \(saturation), brightness: \(brightness)")
                
                // Update button color for real-time feedback
                view.setColorButtonColor(color)
            }
            
        case .ended, .cancelled:
            // Apply the selected color
            if let color = colorWheelView.selectorIndicator.backgroundColor {
                // Log final color
                var hue: CGFloat = 0
                var saturation: CGFloat = 0
                var brightness: CGFloat = 0
                var alpha: CGFloat = 0
                color.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
                print("🔄 Final color - hue: \(hue), sat: \(saturation), brightness: \(brightness)")
                
                updatePhotosWithColor(color)
            }
            
            colorWheelView.hide()
            
        default:
            break
        }
    }
    
    func floatingButtonsDidTapFolder(_ view: FloatingButtonsView) {
        showAlbumPicker()
    }
}

// MARK: - ColorWheelViewDelegate
extension MainViewController: ColorWheelViewDelegate {
    func colorWheelView(_ colorWheel: ColorWheelView, didSelectColor color: UIColor) {
        updatePhotosWithColor(color)
    }
    
    func colorWheelView(_ colorWheel: ColorWheelView, didUpdateColor color: UIColor, withGesture gesture: UILongPressGestureRecognizer) {
        // Real-time color updates during gesture
        floatingButtons.setColorButtonColor(color)
    }
}

// MARK: - PhotoLibraryManagerDelegate
extension MainViewController: PhotoLibraryManagerDelegate {
    func photoLibraryManager(_ manager: PhotoLibraryManager, didUpdateAuth status: PHAuthorizationStatus) {
        if status != .authorized {
            showAccessDeniedAlert()
        }
    }
    
    func photoLibraryManager(_ manager: PhotoLibraryManager, didFetchAssets assets: PHFetchResult<PHAsset>) {
        print("📁 MainViewController received \(assets.count) assets from PhotoLibraryManager")
        if assets.count == 0 {
            let alert = UIAlertController(title: "No Photos", message: "No photos were found in your library.", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
        } else {
            print("📁 Starting batch analysis for \(assets.count) assets")
            analyzePhotos()
        }
    }
    
    func photoLibraryManager(_ manager: PhotoLibraryManager, didFailWithError error: Error) {
        let alert = UIAlertController(title: "Error", message: "Failed to access photo library: \(error.localizedDescription)", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - UICollectionViewDelegate, UICollectionViewDataSource
extension MainViewController: UICollectionViewDataSource, UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return filteredPhotoAssets.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "PhotoCell", for: indexPath) as? PhotoCell else {
            fatalError("Unable to dequeue PhotoCell")
        }
        
        let photoAsset = filteredPhotoAssets[indexPath.item]
        
        // Configure with PhotoAsset
        cell.configure(with: photoAsset.asset, color: photoAsset.averageColor, similarity: photoAsset.similarityValue)
        
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let photoAsset = filteredPhotoAssets[indexPath.item]
        
        // Create dictionary of asset colors for full screen view
        var assetColors: [String: UIColor] = [:]
        if let color = photoAsset.averageColor {
            assetColors[photoAsset.identifier] = color
        }
        
        // Create the full screen controller with just this asset
        let fullScreenVC = FullScreenPhotoViewController(
            orderedAssets: [photoAsset.asset],
            initialIndex: 0,
            assetColors: assetColors
        )
        
        // Present it
        fullScreenVC.modalPresentationStyle = .fullScreen
        present(fullScreenVC, animated: true)
    }
}

extension MainViewController: AlbumPickerViewControllerDelegate {
    func albumPicker(_ picker: AlbumPickerViewController, didSelectCollection collection: PHAssetCollection?) {
        print("📁 Album picker selected: \(collection?.localizedTitle ?? "All Photos")")
        
        // Set the selected collection in PhotoLibraryManager
        PhotoLibraryManager.shared.selectCollection(collection)
        
        // Reset the photo arrays
        print("📁 Clearing photo arrays (before: \(photoAssets.count) assets)")
        photoAssets.removeAll()
        filteredPhotoAssets.removeAll()
        
        // Reload UI
        DispatchQueue.main.async {
            self.collectionView.reloadData()
        }
        
        // Analyze the new batch
        print("📁 Starting analysis of new batch")
        loadExistingData()
    }
}
