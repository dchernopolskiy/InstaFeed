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
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
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

class SinglePhotoViewController: UIViewController, UIGestureRecognizerDelegate {
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

    init(asset: PHAsset, averageColor: UIColor) {
        self.asset = asset
        self.averageColor = averageColor
        self.imageView = UIImageView()
        self.activityIndicator = UIActivityIndicatorView(style: .large)
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupImageView()
        setupCloseButton()
        setupShareButton()
        setupActivityIndicator()
        setupGestureRecognizers()
        view.backgroundColor = averageColor
    }

    private func setupGestureRecognizers() {
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        view.addGestureRecognizer(tapGesture)

        let leftSwipe = UISwipeGestureRecognizer(target: self, action: #selector(handleSwipe(_:)))
        leftSwipe.direction = .left
        view.addGestureRecognizer(leftSwipe)

        let rightSwipe = UISwipeGestureRecognizer(target: self, action: #selector(handleSwipe(_:)))
        rightSwipe.direction = .right
        view.addGestureRecognizer(rightSwipe)

        let upSwipe = UISwipeGestureRecognizer(target: self, action: #selector(handleDismissSwipe(_:)))
        upSwipe.direction = .up
        view.addGestureRecognizer(upSwipe)

        let downSwipe = UISwipeGestureRecognizer(target: self, action: #selector(handleDismissSwipe(_:)))
        downSwipe.direction = .down
        view.addGestureRecognizer(downSwipe)
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
    
    private func setupImageView() {
        view.addSubview(imageView)
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: view.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
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
        let option = PHImageRequestOptions()
        option.deliveryMode = .opportunistic
        option.isNetworkAccessAllowed = true
        option.progressHandler = { (progress, _, _, _) in
            DispatchQueue.main.async {
                print("Download progress: \(progress)")
            }
        }
        
        // Load a lower quality image quickly
        manager.requestImage(for: asset, targetSize: CGSize(width: 300, height: 300), contentMode: .aspectFit, options: option) { [weak self] (image, _) in
            DispatchQueue.main.async {
                self?.imageView.image = image
            }
        }
        
        // Load the full quality image
        manager.requestImage(for: asset, targetSize: PHImageManagerMaximumSize, contentMode: .aspectFit, options: option) { [weak self] (image, info) in
            DispatchQueue.main.async {
                self?.activityIndicator.stopAnimating()
                if let image = image {
                    UIView.transition(with: self?.imageView ?? UIImageView(), duration: 0.3, options: .transitionCrossDissolve, animations: {
                        self?.imageView.image = image
                    }, completion: nil)
                }
            }
        }
    }
    
    @objc private func closeTapped() {
        dismiss(animated: true, completion: nil)
    }
    
    @objc private func shareTapped() {
        guard let image = imageView.image else {
            showAlert(title: "Error", message: "No image available to share.")
            return
        }
        
        let activityViewController = UIActivityViewController(activityItems: [image], applicationActivities: nil)
        
        // For iPad
        if let popoverController = activityViewController.popoverPresentationController {
            popoverController.sourceView = shareButton
            popoverController.sourceRect = shareButton.bounds
        }
        
        // Handle potential errors
        activityViewController.completionWithItemsHandler = { (activityType, completed, returnedItems, error) in
            if let error = error {
                print("Sharing failed with error: \(error.localizedDescription)")
                self.showAlert(title: "Sharing Failed", message: "There was an error while trying to share the image.")
            } else if completed {
                print("Sharing completed successfully.")
            } else {
                print("Sharing cancelled by user.")
            }
        }
        
        present(activityViewController, animated: true, completion: nil)
    }

    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
        present(alert, animated: true, completion: nil)
    }
}
