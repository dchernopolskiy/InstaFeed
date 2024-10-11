import UIKit
import Photos

class FullScreenPhotoViewController: UIPageViewController, UIGestureRecognizerDelegate {
    private var orderedAssets: [PHAsset]
    private var currentIndex: Int

    init(orderedAssets: [PHAsset], initialIndex: Int) {
        self.orderedAssets = orderedAssets
        self.currentIndex = initialIndex
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
        // Set this view controller as the delegate for existing gesture recognizers
        for gestureRecognizer in gestureRecognizers {
            gestureRecognizer.delegate = self
        }
    }
    
    private func photoViewController(at index: Int) -> UIViewController? {
        guard index >= 0 && index < orderedAssets.count else { return nil }
        let vc = SinglePhotoViewController(asset: orderedAssets[index])
        vc.index = index
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
    private let closeButton: UIButton
    private let shareButton: UIButton
    private let activityIndicator: UIActivityIndicatorView
    var index: Int = 0
    
    init(asset: PHAsset) {
        self.asset = asset
        self.imageView = UIImageView()
        self.closeButton = UIButton(type: .system)
        self.shareButton = UIButton(type: .system)
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
    }

    private func setupGestureRecognizers() {
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        tapGesture.delegate = self
        view.addGestureRecognizer(tapGesture)
    }

    @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
        // Toggle visibility of buttons
        let isHidden = !closeButton.isHidden
        closeButton.isHidden = isHidden
        shareButton.isHidden = isHidden
    }

    // MARK: - UIGestureRecognizerDelegate

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
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
        closeButton.setTitle("X", for: .normal)
        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            closeButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            closeButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            closeButton.widthAnchor.constraint(equalToConstant: 44),
            closeButton.heightAnchor.constraint(equalToConstant: 44)
        ])
    }
    
    private func setupShareButton() {
        view.addSubview(shareButton)
        shareButton.setTitle("^", for: .normal)
        shareButton.addTarget(self, action: #selector(shareTapped), for: .touchUpInside)
        shareButton.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            shareButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            shareButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
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
        
        // First, load a lower quality image quickly
        manager.requestImage(for: asset, targetSize: CGSize(width: 300, height: 300), contentMode: .aspectFit, options: option) { [weak self] (image, _) in
            DispatchQueue.main.async {
                self?.imageView.image = image
            }
        }
        
        // Then, load the full quality image
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
        guard let image = imageView.image else { return }
        
        let activityViewController = UIActivityViewController(activityItems: [image], applicationActivities: nil)
        
        // For iPad
        if let popoverController = activityViewController.popoverPresentationController {
            popoverController.sourceView = shareButton
            popoverController.sourceRect = shareButton.bounds
        }
        
        present(activityViewController, animated: true, completion: nil)
    }
}
