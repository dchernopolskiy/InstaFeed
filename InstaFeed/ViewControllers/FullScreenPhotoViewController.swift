import UIKit
import Photos

class FullScreenPhotoViewController: UIPageViewController, UIGestureRecognizerDelegate {
    private var orderedAssets: [PHAsset]
    private var currentIndex: Int
    private var assetColors: [String: UIColor]

    init(orderedAssets: [PHAsset], initialIndex: Int, assetColors: [String: UIColor]) {
        self.orderedAssets = orderedAssets
        self.currentIndex = initialIndex
        self.assetColors = assetColors
        super.init(transitionStyle: .scroll, navigationOrientation: .horizontal, options: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        dataSource = self
        delegate = self
        
        if let initialVC = photoViewController(at: currentIndex) {
            setViewControllers([initialVC], direction: .forward, animated: false, completion: nil)
        }
        
        setupGestureRecognizers()
    }
    
    private func setupGestureRecognizers() {
        for gestureRecognizer in gestureRecognizers ?? [] {
            gestureRecognizer.delegate = self
        }
    }
    
    func goToNextPhoto() {
        if let currentVC = viewControllers?.first as? SinglePhotoViewController,
           let nextVC = pageViewController(self, viewControllerAfter: currentVC) {
            setViewControllers([nextVC], direction: .forward, animated: true, completion: nil)
        }
    }
    
    func goToPreviousPhoto() {
        if let currentVC = viewControllers?.first as? SinglePhotoViewController,
           let previousVC = pageViewController(self, viewControllerBefore: currentVC) {
            setViewControllers([previousVC], direction: .reverse, animated: true, completion: nil)
        }
    }

    private func photoViewController(at index: Int) -> UIViewController? {
        guard index >= 0 && index < orderedAssets.count else { return nil }
        let asset = orderedAssets[index]
        let averageColor = assetColors[asset.localIdentifier] ?? .black
        let vc = SinglePhotoViewController(asset: asset, averageColor: averageColor)
        vc.index = index
        vc.fullScreenParent = self
        return vc
    }

    // MARK: - UIGestureRecognizerDelegate
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        // Get the current SinglePhotoViewController
        if let currentVC = viewControllers?.first as? SinglePhotoViewController,
           let swipeGesture = gestureRecognizer as? UISwipeGestureRecognizer {
            // Check if the current view is zoomed in
            return currentVC.isZoomedOut
        }
        return true
    }
}

extension FullScreenPhotoViewController: UIPageViewControllerDataSource, UIPageViewControllerDelegate {
    func pageViewController(_ pageViewController: UIPageViewController, viewControllerBefore viewController: UIViewController) -> UIViewController? {
        guard let photoVC = viewController as? SinglePhotoViewController else { return nil }
        return photoViewController(at: photoVC.index - 1)
    }
    
    func pageViewController(_ pageViewController: UIPageViewController, viewControllerAfter viewController: UIViewController) -> UIViewController? {
        guard let photoVC = viewController as? SinglePhotoViewController else { return nil }
        return photoViewController(at: photoVC.index + 1)
    }
    
    func pageViewController(_ pageViewController: UIPageViewController, didFinishAnimating finished: Bool, previousViewControllers: [UIViewController], transitionCompleted completed: Bool) {
        if completed,
           let currentPhotoVC = pageViewController.viewControllers?.first as? SinglePhotoViewController {
            currentIndex = currentPhotoVC.index
        }
    }
}

class SinglePhotoViewController: UIViewController, UIGestureRecognizerDelegate, UIScrollViewDelegate {
    private let scrollView: UIScrollView
    private let imageView: UIImageView
    private let asset: PHAsset
    private let averageColor: UIColor
    private let activityIndicator: UIActivityIndicatorView
    var index: Int = 0
    
    weak var fullScreenParent: FullScreenPhotoViewController?

    lazy var closeButton: UIButton = {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: "xmark.circle.fill"), for: .normal)
        button.tintColor = .white
        button.backgroundColor = .clear
        button.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.layer.shadowColor = UIColor.black.cgColor
        button.layer.shadowOffset = CGSize(width: 0, height: 1)
        button.layer.shadowOpacity = 0.3
        button.layer.shadowRadius = 2
        return button
    }()
        
    lazy var shareButton: UIButton = {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: "square.and.arrow.up"), for: .normal)
        button.tintColor = .white
        button.backgroundColor = .clear
        button.addTarget(self, action: #selector(shareTapped), for: .touchUpInside)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.layer.shadowColor = UIColor.black.cgColor
        button.layer.shadowOffset = CGSize(width: 0, height: 1)
        button.layer.shadowOpacity = 0.3
        button.layer.shadowRadius = 2
        return button
        
    }()

    var isZoomedOut: Bool {
        return scrollView.zoomScale <= scrollView.minimumZoomScale
    }
    
    init(asset: PHAsset, averageColor: UIColor) {
        self.scrollView = UIScrollView()
        self.asset = asset
        self.averageColor = averageColor
        self.imageView = UIImageView()
        self.activityIndicator = UIActivityIndicatorView(style: .large)
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private var fullResolutionImage: UIImage?
    private let imageRequestOptions: PHImageRequestOptions = {
        let options = PHImageRequestOptions()
        options.deliveryMode = .opportunistic
        options.isNetworkAccessAllowed = true
        options.isSynchronous = false
        return options
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupScrollView()
        setupImageView()
        setupCloseButton()
        setupShareButton()
        setupActivityIndicator()
        setupGestureRecognizers()
        view.backgroundColor = averageColor
        //loading the image so there's no delay when using share button
        loadFullResolutionImage()
    }

    private func setupGestureRecognizers() {
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        view.addGestureRecognizer(tapGesture)

        // Only allow swipe gestures when not zoomed in
        let leftSwipe = UISwipeGestureRecognizer(target: self, action: #selector(handleSwipe(_:)))
        leftSwipe.direction = .left
        leftSwipe.delegate = self
        view.addGestureRecognizer(leftSwipe)

        let rightSwipe = UISwipeGestureRecognizer(target: self, action: #selector(handleSwipe(_:)))
        rightSwipe.direction = .right
        rightSwipe.delegate = self
        view.addGestureRecognizer(rightSwipe)

        let upSwipe = UISwipeGestureRecognizer(target: self, action: #selector(handleDismissSwipe(_:)))
        upSwipe.direction = .up
        upSwipe.delegate = self
        view.addGestureRecognizer(upSwipe)

        let downSwipe = UISwipeGestureRecognizer(target: self, action: #selector(handleDismissSwipe(_:)))
        downSwipe.direction = .down
        downSwipe.delegate = self
        view.addGestureRecognizer(downSwipe)
    }
    
    private func setupScrollView() {
        view.addSubview(scrollView)
        scrollView.delegate = self
        scrollView.minimumZoomScale = 1.0
        scrollView.maximumZoomScale = 4.0
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.contentInsetAdjustmentBehavior = .never
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        let doubleTapGesture = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap(_:)))
        doubleTapGesture.numberOfTapsRequired = 2
        scrollView.addGestureRecognizer(doubleTapGesture)
    }
    
    @objc private func handleDoubleTap(_ gesture: UITapGestureRecognizer) {
        if scrollView.zoomScale > scrollView.minimumZoomScale {
            // If zoomed in, zoom out
            scrollView.setZoomScale(scrollView.minimumZoomScale, animated: true)
        } else {
            // If zoomed out, zoom in to 2x at the tap point
            let location = gesture.location(in: imageView)
            let rect = CGRect(
                x: location.x - (scrollView.bounds.size.width / 4),
                y: location.y - (scrollView.bounds.size.height / 4),
                width: scrollView.bounds.size.width / 2,
                height: scrollView.bounds.size.height / 2
            )
            scrollView.zoom(to: rect, animated: true)
        }
    }
    
    @objc func shareTapped() {
        guard let image = imageView.image else { return }
        
        let activityViewController = UIActivityViewController(
            activityItems: [image],
            applicationActivities: nil
        )
        
        // For iPad support
        if let popoverController = activityViewController.popoverPresentationController {
            popoverController.sourceView = view
            popoverController.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 0, height: 0)
            popoverController.permittedArrowDirections = []
        }
        
        present(activityViewController, animated: true)
    }
    
    // MARK: - UIScrollViewDelegate
    
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return imageView
    }
    
    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        // Keep the image centered while zooming
        let offsetX = max((scrollView.bounds.width - scrollView.contentSize.width) * 0.5, 0)
        let offsetY = max((scrollView.bounds.height - scrollView.contentSize.height) * 0.5, 0)
        
        scrollView.contentInset = UIEdgeInsets(
            top: offsetY,
            left: offsetX,
            bottom: offsetY,
            right: offsetX
        )
    }
    
    
    private func setupImageView() {
        scrollView.addSubview(imageView)
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            imageView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
            imageView.heightAnchor.constraint(equalTo: scrollView.heightAnchor),
            imageView.centerXAnchor.constraint(equalTo: scrollView.centerXAnchor),
            imageView.centerYAnchor.constraint(equalTo: scrollView.centerYAnchor)
        ])
    }

    @objc private func handleSwipe(_ gesture: UISwipeGestureRecognizer) {
        guard let parent = fullScreenParent else { return }
        if gesture.direction == .left {
            parent.goToNextPhoto()
        } else if gesture.direction == .right {
            parent.goToPreviousPhoto()
        }
    }

    @objc private func handleDismissSwipe(_ gesture: UISwipeGestureRecognizer) {
        dismiss(animated: true, completion: nil)
    }

    @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
        let isHidden = !closeButton.isHidden
        closeButton.isHidden = isHidden
        shareButton.isHidden = isHidden
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        loadImage()
    }
    
    private func setupActivityIndicator() {
        view.addSubview(activityIndicator)
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            activityIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }
    
    private func setupCloseButton() {
        view.addSubview(closeButton)
        NSLayoutConstraint.activate([
            closeButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            closeButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            closeButton.widthAnchor.constraint(equalToConstant: 44),
            closeButton.heightAnchor.constraint(equalToConstant: 44)
        ])
    }
    
    private func setupShareButton() {
        view.addSubview(shareButton)
        NSLayoutConstraint.activate([
            shareButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),
            shareButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            shareButton.widthAnchor.constraint(equalToConstant: 44),
            shareButton.heightAnchor.constraint(equalToConstant: 44)
        ])
    }
    
    private func loadImage() {
        activityIndicator.startAnimating()
        
        let manager = PHImageManager.default()
        
        // Load a lower quality image quickly
        manager.requestImage(
            for: asset,
            targetSize: CGSize(width: 300, height: 300),
            contentMode: .aspectFit,
            options: imageRequestOptions
        ) { [weak self] (image, _) in
            DispatchQueue.main.async {
                self?.imageView.image = image
            }
        }
    }
    
        
    private func loadFullResolutionImage() {
        let manager = PHImageManager.default()
        
        // Show the activity indicator
        activityIndicator.startAnimating()
        
        // Load the full quality image
        manager.requestImage(
            for: asset,
            targetSize: PHImageManagerMaximumSize,
            contentMode: .aspectFit,
            options: imageRequestOptions
        ) { [weak self] (image, info) in
            DispatchQueue.main.async {
                self?.activityIndicator.stopAnimating()
                if let image = image {
                    self?.fullResolutionImage = image
                    UIView.transition(
                        with: self?.imageView ?? UIImageView(),
                        duration: 0.3,
                        options: .transitionCrossDissolve,
                        animations: {
                            self?.imageView.image = image
                        },
                        completion: nil
                    )
                }
            }
        }
    }
    
    @objc private func closeTapped() {
        dismiss(animated: true, completion: nil)
    
    }


    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
        present(alert, animated: true, completion: nil)
    }
}

// MARK: - Photos App Integration
extension SinglePhotoViewController {
    
    func openInPhotosApp() {
        // Try URL scheme first
        if let url = URL(string: "photos-redirect://"), UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
            return
        }
        
        // Otherwise use document interaction controller
        exportAsTemporaryFile()
    }
    
    private func exportAsTemporaryFile() {
        activityIndicator.startAnimating()
        
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.isNetworkAccessAllowed = true
        options.isSynchronous = false
        
        PHImageManager.default().requestImageDataAndOrientation(for: asset, options: options) { [weak self] (data, _, _, _) in
            guard let self = self, let imageData = data else {
                DispatchQueue.main.async {
                    self?.activityIndicator.stopAnimating()
                    self?.showAlert(title: "Error", message: "Could not get image data")
                }
                return
            }
            
            let temporaryFileURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(self.asset.localIdentifier).jpg")
            
            do {
                try imageData.write(to: temporaryFileURL)
                
                DispatchQueue.main.async {
                    self.activityIndicator.stopAnimating()
                    
                    let docController = UIDocumentInteractionController(url: temporaryFileURL)
                    docController.delegate = self
                    docController.presentPreview(animated: true)
                }
            } catch {
                DispatchQueue.main.async {
                    self.activityIndicator.stopAnimating()
                    self.showAlert(title: "Error", message: "Error creating temporary file: \(error.localizedDescription)")
                }
            }
        }
    }
    
    @objc func enhancedShareTapped() {
        // Show activity indicator
        activityIndicator.startAnimating()
        
        // Use cached full resolution image if available
        if let fullResImage = fullResolutionImage {
            presentEnhancedShareSheet(with: fullResImage)
            return
        }
        
        // Otherwise, request it again
        let manager = PHImageManager.default()
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.isNetworkAccessAllowed = true
        options.isSynchronous = false
        
        manager.requestImage(
            for: asset,
            targetSize: PHImageManagerMaximumSize,
            contentMode: .aspectFit,
            options: options
        ) { [weak self] (image, _) in
            DispatchQueue.main.async {
                self?.activityIndicator.stopAnimating()
                if let image = image {
                    self?.fullResolutionImage = image
                    self?.presentEnhancedShareSheet(with: image)
                } else {
                    self?.showAlert(title: "Error", message: "No image available to share.")
                }
            }
        }
    }
    
    private func presentEnhancedShareSheet(with image: UIImage) {
        // Create custom activity for "Open in Photos"
        let openInPhotosActivity = OpenInPhotosActivity()
        openInPhotosActivity.completionHandler = { [weak self] in
            self?.openInPhotosApp()
        }
        
        let activityViewController = UIActivityViewController(
            activityItems: [image],
            applicationActivities: [openInPhotosActivity]
        )
        
        // For iPad
        if let popoverController = activityViewController.popoverPresentationController {
            popoverController.sourceView = shareButton
            popoverController.sourceRect = shareButton.bounds
        }
        
        present(activityViewController, animated: true) {
            self.activityIndicator.stopAnimating()
        }
    }
}

extension SinglePhotoViewController: UIDocumentInteractionControllerDelegate {
    func documentInteractionControllerViewControllerForPreview(_ controller: UIDocumentInteractionController) -> UIViewController {
        return self
    }
}
