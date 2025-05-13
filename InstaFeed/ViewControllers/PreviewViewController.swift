//
//  PreviewViewController.swift
//  InstaFeed
//
//  Created by Dan Chernopolskii on 5/7/25.
//


import UIKit
import Photos

class PreviewViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegate {
    
    // MARK: - Properties
    private var collectionView: UICollectionView!
    private var orderedAssets: [PHAsset]
    private var assetColors: [String: UIColor]
    private var username: String = "yourusername"
    private var exportCancelled = false
    
    private let backButton = UIButton(type: .system)
    private let shareButton = UIButton(type: .system)
    private let exportButton = UIButton(type: .system)
    
    // MARK: - Initialization
    init(orderedAssets: [PHAsset], assetColors: [String: UIColor]) {
        self.orderedAssets = orderedAssets
        self.assetColors = assetColors
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Lifecycle Methods
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupDragDrop()
    }
    
    // MARK: - UI Setup
    private func setupUI() {
        view.backgroundColor = .black
        
        setupNavigationBar()
        setupProfileHeader()
        setupGridCollectionView()
        setupGradientPreview()
        setupBottomActionBar()
    }
    
    func setupDragDrop() {
        collectionView.dragDelegate = self
        collectionView.dropDelegate = self
        collectionView.dragInteractionEnabled = true
    }
    
    private func setupNavigationBar() {
        // Create custom nav bar
        let navBar = UIView()
        navBar.backgroundColor = .black
        view.addSubview(navBar)
        
        // Back button
        backButton.setImage(UIImage(systemName: "arrow.left"), for: .normal)
        backButton.tintColor = .white
        backButton.addTarget(self, action: #selector(backButtonTapped), for: .touchUpInside)
        
        // Title
        let titleLabel = UILabel()
        titleLabel.text = "Feed Preview"
        titleLabel.textColor = .white
        titleLabel.font = UIFont.systemFont(ofSize: 17, weight: .semibold)
        
        // Share button
        shareButton.setImage(UIImage(systemName: "square.and.arrow.up"), for: .normal)
        shareButton.tintColor = .white
        shareButton.backgroundColor = UIColor(red: 0.5, green: 0.2, blue: 0.8, alpha: 1.0)
        shareButton.layer.cornerRadius = 16
        shareButton.addTarget(self, action: #selector(shareButtonTapped), for: .touchUpInside)
        
        // Add to navbar
        navBar.addSubview(backButton)
        navBar.addSubview(titleLabel)
        navBar.addSubview(shareButton)
        
        // Layout
        navBar.translatesAutoresizingMaskIntoConstraints = false
        backButton.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        shareButton.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            navBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            navBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            navBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            navBar.heightAnchor.constraint(equalToConstant: 44),
            
            backButton.leadingAnchor.constraint(equalTo: navBar.leadingAnchor, constant: 16),
            backButton.centerYAnchor.constraint(equalTo: navBar.centerYAnchor),
            backButton.widthAnchor.constraint(equalToConstant: 44),
            backButton.heightAnchor.constraint(equalToConstant: 44),
            
            titleLabel.centerXAnchor.constraint(equalTo: navBar.centerXAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: navBar.centerYAnchor),
            
            shareButton.trailingAnchor.constraint(equalTo: navBar.trailingAnchor, constant: -16),
            shareButton.centerYAnchor.constraint(equalTo: navBar.centerYAnchor),
            shareButton.widthAnchor.constraint(equalToConstant: 32),
            shareButton.heightAnchor.constraint(equalToConstant: 32)
        ])
    }
    
    private func setupProfileHeader() {
        // Profile container
        let profileContainer = UIView()
        profileContainer.backgroundColor = .black
        view.addSubview(profileContainer)
        
        // Profile image
        let profileImageView = UIImageView()
        profileImageView.backgroundColor = UIColor(white: 0.2, alpha: 1.0)
        profileImageView.layer.cornerRadius = 40
        profileImageView.clipsToBounds = true
        profileImageView.image = UIImage(systemName: "person.crop.circle.fill")
        profileImageView.tintColor = .white
        
        // Username label
        let usernameLabel = UILabel()
        usernameLabel.text = username
        usernameLabel.textColor = .white
        usernameLabel.font = UIFont.systemFont(ofSize: 15, weight: .semibold)
        
        // Name label
        let nameLabel = UILabel()
        nameLabel.text = "Your Name"
        nameLabel.textColor = UIColor(white: 0.7, alpha: 1.0)
        nameLabel.font = UIFont.systemFont(ofSize: 13, weight: .regular)
        
        // Add to container
        profileContainer.addSubview(profileImageView)
        profileContainer.addSubview(usernameLabel)
        profileContainer.addSubview(nameLabel)
        
        // Layout
        profileContainer.translatesAutoresizingMaskIntoConstraints = false
        profileImageView.translatesAutoresizingMaskIntoConstraints = false
        usernameLabel.translatesAutoresizingMaskIntoConstraints = false
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            profileContainer.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 44),
            profileContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            profileContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            profileContainer.heightAnchor.constraint(equalToConstant: 100),
            
            profileImageView.leadingAnchor.constraint(equalTo: profileContainer.leadingAnchor, constant: 16),
            profileImageView.centerYAnchor.constraint(equalTo: profileContainer.centerYAnchor),
            profileImageView.widthAnchor.constraint(equalToConstant: 80),
            profileImageView.heightAnchor.constraint(equalToConstant: 80),
            
            usernameLabel.leadingAnchor.constraint(equalTo: profileImageView.trailingAnchor, constant: 16),
            usernameLabel.topAnchor.constraint(equalTo: profileImageView.topAnchor, constant: 20),
            
            nameLabel.leadingAnchor.constraint(equalTo: profileImageView.trailingAnchor, constant: 16),
            nameLabel.topAnchor.constraint(equalTo: usernameLabel.bottomAnchor, constant: 4)
        ])
    }
    
    private func setupGridCollectionView() {
        // Create grid layout (3x3 Instagram style)
        let layout = UICollectionViewFlowLayout()
        let screenWidth = UIScreen.main.bounds.width
        let cellWidth = screenWidth / 3  // Force 3 columns
        
        layout.itemSize = CGSize(width: cellWidth - 1, height: cellWidth - 1)  // -1 for spacing
        layout.minimumInteritemSpacing = 1
        layout.minimumLineSpacing = 1
        layout.sectionInset = UIEdgeInsets(top: 1, left: 0, bottom: 1, right: 0)
        
        // Create collection view
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.backgroundColor = .black
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.register(PreviewCell.self, forCellWithReuseIdentifier: "PreviewCell")
        view.addSubview(collectionView)
        
        // Layout - make it full width and proper height
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 144),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -80)
        ])
    }
    
    private func setupGradientPreview() {
        // Container for gradient preview
        let gradientContainer = UIView()
        gradientContainer.backgroundColor = UIColor(white: 0.1, alpha: 1.0)
        view.addSubview(gradientContainer)
        
        // Create gradient bar
        let gradientBar = UIView()
        gradientBar.layer.cornerRadius = 8
        gradientBar.clipsToBounds = true
        gradientContainer.addSubview(gradientBar)
        
        // Add gradient layer
        let gradientLayer = CAGradientLayer()
        gradientLayer.frame = CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width - 32, height: 16)
        gradientLayer.startPoint = CGPoint(x: 0.0, y: 0.5)
        gradientLayer.endPoint = CGPoint(x: 1.0, y: 0.5)
        
        // Create colors from assets
        var colors: [CGColor] = []
        for asset in orderedAssets.prefix(10) {
            if let color = assetColors[asset.localIdentifier] {
                colors.append(color.cgColor)
            }
        }
        
        // If we have colors, set them
        if !colors.isEmpty {
            gradientLayer.colors = colors
            gradientBar.layer.addSublayer(gradientLayer)
        }
        
        // Layout
        gradientContainer.translatesAutoresizingMaskIntoConstraints = false
        gradientBar.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            gradientContainer.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -66),
            gradientContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            gradientContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            gradientContainer.heightAnchor.constraint(equalToConstant: 40),
            
            gradientBar.centerYAnchor.constraint(equalTo: gradientContainer.centerYAnchor),
            gradientBar.leadingAnchor.constraint(equalTo: gradientContainer.leadingAnchor, constant: 16),
            gradientBar.trailingAnchor.constraint(equalTo: gradientContainer.trailingAnchor, constant: -16),
            gradientBar.heightAnchor.constraint(equalToConstant: 16)
        ])
    }
    
    private func setupBottomActionBar() {
        // Bottom action bar
        let actionBar = UIView()
        actionBar.backgroundColor = UIColor(white: 0.1, alpha: 1.0)
        view.addSubview(actionBar)
        
        // Grid view button
        let gridButton = UIButton(type: .system)
        gridButton.setTitle("Grid View", for: .normal)
        gridButton.setImage(UIImage(systemName: "square.grid.3x3"), for: .normal)
        gridButton.tintColor = .white
        gridButton.backgroundColor = UIColor(white: 0.2, alpha: 1.0)
        gridButton.layer.cornerRadius = 8
        gridButton.titleEdgeInsets = UIEdgeInsets(top: 0, left: 8, bottom: 0, right: 0)
        gridButton.contentEdgeInsets = UIEdgeInsets(top: 8, left: 12, bottom: 8, right: 12)
        
        // Action buttons container
        let actionsContainer = UIView()
        actionBar.addSubview(gridButton)
        actionBar.addSubview(actionsContainer)
        
        // Cancel button
        let cancelButton = UIButton(type: .system)
        cancelButton.setImage(UIImage(systemName: "xmark.circle"), for: .normal)
        cancelButton.tintColor = .white
        cancelButton.backgroundColor = UIColor.red.withAlphaComponent(0.8)
        cancelButton.layer.cornerRadius = 20
        cancelButton.addTarget(self, action: #selector(cancelButtonTapped), for: .touchUpInside)
        
        // Export button
        exportButton.setImage(UIImage(systemName: "arrow.down.circle"), for: .normal)
        exportButton.tintColor = .white
        exportButton.backgroundColor = UIColor.purple.withAlphaComponent(0.8)
        exportButton.layer.cornerRadius = 20
        exportButton.addTarget(self, action: #selector(exportButtonTapped), for: .touchUpInside)
        
        // Save button
        let saveButton = UIButton(type: .system)
        saveButton.setImage(UIImage(systemName: "checkmark.circle"), for: .normal)
        saveButton.tintColor = .white
        saveButton.backgroundColor = UIColor.green.withAlphaComponent(0.8)
        saveButton.layer.cornerRadius = 20
        saveButton.addTarget(self, action: #selector(saveButtonTapped), for: .touchUpInside)
        
        // Add to container
        actionsContainer.addSubview(cancelButton)
        actionsContainer.addSubview(exportButton)
        actionsContainer.addSubview(saveButton)
        
        // Layout
        actionBar.translatesAutoresizingMaskIntoConstraints = false
        gridButton.translatesAutoresizingMaskIntoConstraints = false
        actionsContainer.translatesAutoresizingMaskIntoConstraints = false
        cancelButton.translatesAutoresizingMaskIntoConstraints = false
        exportButton.translatesAutoresizingMaskIntoConstraints = false
        saveButton.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            actionBar.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            actionBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            actionBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            actionBar.heightAnchor.constraint(equalToConstant: 60),
            
            gridButton.leadingAnchor.constraint(equalTo: actionBar.leadingAnchor, constant: 16),
            gridButton.centerYAnchor.constraint(equalTo: actionBar.centerYAnchor),
            
            actionsContainer.trailingAnchor.constraint(equalTo: actionBar.trailingAnchor, constant: -16),
            actionsContainer.centerYAnchor.constraint(equalTo: actionBar.centerYAnchor),
            actionsContainer.heightAnchor.constraint(equalToConstant: 40),
            
            cancelButton.leadingAnchor.constraint(equalTo: actionsContainer.leadingAnchor),
            cancelButton.centerYAnchor.constraint(equalTo: actionsContainer.centerYAnchor),
            cancelButton.widthAnchor.constraint(equalToConstant: 40),
            cancelButton.heightAnchor.constraint(equalToConstant: 40),
            
            exportButton.leadingAnchor.constraint(equalTo: cancelButton.trailingAnchor, constant: 16),
            exportButton.centerYAnchor.constraint(equalTo: actionsContainer.centerYAnchor),
            exportButton.widthAnchor.constraint(equalToConstant: 40),
            exportButton.heightAnchor.constraint(equalToConstant: 40),
            
            saveButton.leadingAnchor.constraint(equalTo: exportButton.trailingAnchor, constant: 16),
            saveButton.centerYAnchor.constraint(equalTo: actionsContainer.centerYAnchor),
            saveButton.widthAnchor.constraint(equalToConstant: 40),
            saveButton.heightAnchor.constraint(equalToConstant: 40)
        ])
    }
    
    // MARK: - Collection View Data Source
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return orderedAssets.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "PreviewCell", for: indexPath) as? PreviewCell else {
            return UICollectionViewCell()
        }
        
        let asset = orderedAssets[indexPath.item]
        let color = assetColors[asset.localIdentifier]
        
        // Configure using PreviewCell's configure method
        cell.configure(with: asset, color: color, index: indexPath.item)
        
        return cell
    }
    
    // MARK: - UICollectionViewDelegate
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        // Show options for reordering or removing
        let asset = orderedAssets[indexPath.item]
        
        let alert = UIAlertController(title: "Photo #\(indexPath.item + 1)", message: "What would you like to do?", preferredStyle: .actionSheet)
        
        alert.addAction(UIAlertAction(title: "Move Up", style: .default) { [weak self] _ in
            self?.moveAsset(at: indexPath.item, offset: -1)
        })
        
        alert.addAction(UIAlertAction(title: "Move Down", style: .default) { [weak self] _ in
            self?.moveAsset(at: indexPath.item, offset: 1)
        })
        
        alert.addAction(UIAlertAction(title: "Remove", style: .destructive) { [weak self] _ in
            self?.removeAsset(at: indexPath.item)
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        if let popoverController = alert.popoverPresentationController {
            if let cell = collectionView.cellForItem(at: indexPath) {
                popoverController.sourceView = cell
                popoverController.sourceRect = cell.bounds
            }
        }
        
        present(alert, animated: true)
    }
    
    // MARK: - Actions
    @objc private func backButtonTapped() {
        dismiss(animated: true)
    }
    
    @objc private func shareButtonTapped() {
        // Share feed preview as image
        let renderer = UIGraphicsImageRenderer(bounds: collectionView.bounds)
        let image = renderer.image { context in
            collectionView.drawHierarchy(in: collectionView.bounds, afterScreenUpdates: true)
        }
        
        let activityVC = UIActivityViewController(activityItems: [image], applicationActivities: nil)
        present(activityVC, animated: true)
    }
    
    @objc private func cancelButtonTapped() {
        dismiss(animated: true)
    }
    
    @objc private func exportButtonTapped() {
        // Export photos in order
        let alert = UIAlertController(title: "Export Photos", message: "Where would you like to save these photos?", preferredStyle: .actionSheet)
        
        alert.addAction(UIAlertAction(title: "Save to Photos", style: .default) { [weak self] _ in
            self?.saveToPhotos()
        })
        
        alert.addAction(UIAlertAction(title: "Share All", style: .default) { [weak self] _ in
            self?.shareAllPhotos()
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        if let popoverController = alert.popoverPresentationController {
            popoverController.sourceView = exportButton
            popoverController.sourceRect = exportButton.bounds
        }
        
        present(alert, animated: true)
    }
    
    @objc private func saveButtonTapped() {
        // Save the current order
        let alert = UIAlertController(title: "Sequence Saved", message: "Your color sequence has been saved.", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    // MARK: - Helper Methods
    private func moveAsset(at index: Int, offset: Int) {
        let newIndex = index + offset
        
        // Check bounds
        guard newIndex >= 0 && newIndex < orderedAssets.count else { return }
        
        // Reorder the array
        let asset = orderedAssets.remove(at: index)
        orderedAssets.insert(asset, at: newIndex)
        
        // Update UI
        collectionView.performBatchUpdates({
            collectionView.moveItem(at: IndexPath(item: index, section: 0), to: IndexPath(item: newIndex, section: 0))
        }, completion: nil)
        
        // Update gradient preview
        setupGradientPreview()
    }
    
    private func removeAsset(at index: Int) {
        // Remove from array
        orderedAssets.remove(at: index)
        
        // Update UI
        collectionView.performBatchUpdates({
            collectionView.deleteItems(at: [IndexPath(item: index, section: 0)])
        }, completion: nil)
        
        // Update gradient preview
        setupGradientPreview()
    }
    
    private func saveToPhotos() {
        // Implementation for saving photos to library in order
    }
    
    private func shareAllPhotos() {
        // Implementation for sharing all photos
    }
}

// MARK: - Drag and Drop Support
extension PreviewViewController: UICollectionViewDragDelegate, UICollectionViewDropDelegate {
    // MARK: - UICollectionViewDragDelegate
    func collectionView(_ collectionView: UICollectionView, itemsForBeginning session: UIDragSession, at indexPath: IndexPath) -> [UIDragItem] {
        let asset = orderedAssets[indexPath.item]
        let itemProvider = NSItemProvider(object: asset.localIdentifier as NSString)
        let dragItem = UIDragItem(itemProvider: itemProvider)
        dragItem.localObject = asset
        return [dragItem]
    }
    
    // MARK: - UICollectionViewDropDelegate
    func collectionView(_ collectionView: UICollectionView, dropSessionDidUpdate session: UIDropSession, withDestinationIndexPath destinationIndexPath: IndexPath?) -> UICollectionViewDropProposal {
        if session.localDragSession != nil {
            return UICollectionViewDropProposal(operation: .move, intent: .insertAtDestinationIndexPath)
        }
        return UICollectionViewDropProposal(operation: .forbidden)
    }
    
    func collectionView(_ collectionView: UICollectionView, performDropWith coordinator: UICollectionViewDropCoordinator) {
        guard let destinationIndexPath = coordinator.destinationIndexPath else { return }
        
        for item in coordinator.items {
            guard let sourceIndexPath = item.sourceIndexPath,
                  let asset = item.dragItem.localObject as? PHAsset else { continue }
            
            // Update the data source
            orderedAssets.remove(at: sourceIndexPath.item)
            orderedAssets.insert(asset, at: destinationIndexPath.item)
            
            // Update the collection view
            collectionView.performBatchUpdates({
                collectionView.deleteItems(at: [sourceIndexPath])
                collectionView.insertItems(at: [destinationIndexPath])
            })
            
            // Notify coordinator of movement
            coordinator.drop(item.dragItem, toItemAt: destinationIndexPath)
            
            // Update gradient preview
            setupGradientPreview()
        }
    }
}

// MARK: - Export Functionality
extension PreviewViewController {
    
    @objc func enhancedExportButtonTapped() {
        let alert = UIAlertController(title: "Export Photos", message: "Choose an export option", preferredStyle: .actionSheet)
        
        alert.addAction(UIAlertAction(title: "Save to Photos App", style: .default) { [weak self] _ in
            self?.saveToPhotosAlbum()
        })
        
        alert.addAction(UIAlertAction(title: "Share Feed Grid", style: .default) { [weak self] _ in
            self?.shareGridImage()
        })
        
        alert.addAction(UIAlertAction(title: "Share All Photos", style: .default) { [weak self] _ in
            self?.shareIndividualPhotos()
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        if let popoverController = alert.popoverPresentationController {
            popoverController.sourceView = exportButton
            popoverController.sourceRect = exportButton.bounds
        }
        
        present(alert, animated: true)
    }
    
    func saveToPhotosAlbum() {
        // Show loading indicator
        let loadingAlert = UIAlertController(title: "Exporting Photos", message: "Please wait...", preferredStyle: .alert)
        loadingAlert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { [weak self] _ in
            self?.exportCancelled = true
        })
        present(loadingAlert, animated: true)
        
        exportCancelled = false
        
        // Create album or use existing one
        createOrFetchAlbum(named: "InstaFeed") { [weak self] album in
            guard let self = self, !self.exportCancelled else { return }
            
            let totalAssets = self.orderedAssets.count
            var exportedCount = 0
            
            for (index, asset) in self.orderedAssets.enumerated() {
                if self.exportCancelled { break }
                
                // Request full-size image
                PHImageManager.default().requestImageDataAndOrientation(for: asset, options: nil) { [weak self] data, _, _, _ in
                    guard let self = self, !self.exportCancelled, let imageData = data, let image = UIImage(data: imageData) else {
                        exportedCount += 1
                        
                        // Check if we're done
                        if exportedCount == totalAssets {
                            self?.finishExport(album: album)
                        }
                        return
                    }
                    
                    // Add to album
                    PHPhotoLibrary.shared().performChanges({
                        let request = PHAssetChangeRequest.creationRequestForAsset(from: image)
                        if let album = album, let placeholder = request.placeholderForCreatedAsset {
                            let albumChangeRequest = PHAssetCollectionChangeRequest(for: album)
                            albumChangeRequest?.addAssets([placeholder] as NSArray)
                        }
                    }) { success, error in
                        if let error = error {
                            print("Error adding photo to album: \(error.localizedDescription)")
                        }
                        
                        exportedCount += 1
                        
                        // Update loading message
                        DispatchQueue.main.async {
                            loadingAlert.message = "Exporting photos: \(exportedCount)/\(totalAssets)"
                        }
                        
                        // Check if we're done
                        if exportedCount == totalAssets {
                            self.finishExport(album: album)
                        }
                    }
                }
            }
        }
    }
    
    func shareGridImage() {
        // Generate an image of the grid
        let renderer = UIGraphicsImageRenderer(bounds: collectionView.bounds)
        let gridImage = renderer.image { context in
            collectionView.drawHierarchy(in: collectionView.bounds, afterScreenUpdates: true)
        }
        
        // Share the image
        let activityVC = UIActivityViewController(activityItems: [gridImage], applicationActivities: nil)
        if let popoverController = activityVC.popoverPresentationController {
            popoverController.sourceView = exportButton
            popoverController.sourceRect = exportButton.bounds
        }
        
        present(activityVC, animated: true)
    }
    
    func shareIndividualPhotos() {
        // Create array of images to share
        var imagesToShare: [UIImage] = []
        let group = DispatchGroup()
        
        // Show loading indicator
        let loadingAlert = UIAlertController(title: "Preparing Photos", message: "Please wait...", preferredStyle: .alert)
        present(loadingAlert, animated: true)
        
        for asset in orderedAssets {
            group.enter()
            
            PHImageManager.default().requestImage(
                for: asset,
                targetSize: PHImageManagerMaximumSize,
                contentMode: .aspectFit,
                options: nil
            ) { image, _ in
                if let image = image {
                    imagesToShare.append(image)
                }
                group.leave()
            }
        }
        
        group.notify(queue: .main) { [weak self] in
            self?.dismiss(animated: true) {
                let activityVC = UIActivityViewController(activityItems: imagesToShare, applicationActivities: nil)
                if let popoverController = activityVC.popoverPresentationController {
                    popoverController.sourceView = self?.exportButton
                    popoverController.sourceRect = self?.exportButton.bounds ?? .zero
                }
                
                self?.present(activityVC, animated: true)
            }
        }
    }
    
    private func createOrFetchAlbum(named name: String, completion: @escaping (PHAssetCollection?) -> Void) {
        // Check if album already exists
        let fetchOptions = PHFetchOptions()
        fetchOptions.predicate = NSPredicate(format: "title = %@", name)
        let collection = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .any, options: fetchOptions)
        
        if let album = collection.firstObject {
            completion(album)
            return
        }
        
        // Create new album
        var albumPlaceholder: PHObjectPlaceholder?
        
        PHPhotoLibrary.shared().performChanges({
            let createAlbumRequest = PHAssetCollectionChangeRequest.creationRequestForAssetCollection(withTitle: name)
            albumPlaceholder = createAlbumRequest.placeholderForCreatedAssetCollection
        }) { success, error in
            if success, let placeholder = albumPlaceholder {
                let fetchResult = PHAssetCollection.fetchAssetCollections(withLocalIdentifiers: [placeholder.localIdentifier], options: nil)
                completion(fetchResult.firstObject)
            } else {
                completion(nil)
            }
        }
    }
    
    private func finishExport(album: PHAssetCollection?) {
        DispatchQueue.main.async { [weak self] in
            self?.dismiss(animated: true) {
                let successAlert = UIAlertController(
                    title: "Export Complete",
                    message: album != nil ? "Your photos have been saved to the \"InstaFeed\" album." : "Your photos have been saved to your library.",
                    preferredStyle: .alert
                )
                
                successAlert.addAction(UIAlertAction(title: "OK", style: .default))
                successAlert.addAction(UIAlertAction(title: "Open Photos", style: .default) { _ in
                    if let url = URL(string: "photos://") {
                        UIApplication.shared.open(url)
                    }
                })
                
                self?.present(successAlert, animated: true)
            }
        }
    }
}
