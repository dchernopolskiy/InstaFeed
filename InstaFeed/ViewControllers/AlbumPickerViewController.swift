//
//  AlbumPickerViewControllerDelegate.swift
//  InstaFeed
//
//  Created by Dan Chernopolskii on 5/8/25.
//


// AlbumPickerViewController.swift
import UIKit
import Photos

protocol AlbumPickerViewControllerDelegate: AnyObject {
    func albumPicker(_ picker: AlbumPickerViewController, didSelectCollection collection: PHAssetCollection?)
}

class AlbumPickerViewController: UITableViewController {
    
    // MARK: - Properties
    private var albums: [PHAssetCollection] = []
    weak var delegate: AlbumPickerViewControllerDelegate?
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setup()
        fetchAlbums()
    }
    
    // MARK: - Setup
    private func setup() {
        title = "Select Album"
        
        // Configure table view
        tableView.backgroundColor = .black
        tableView.separatorStyle = .singleLine
        tableView.separatorColor = UIColor(white: 0.2, alpha: 1.0)
        tableView.register(AlbumCell.self, forCellReuseIdentifier: "AlbumCell")
        
        // Add cancel button
        navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancelTapped))
    }
    
    private func fetchAlbums() {
        // Fetch user albums
        let userAlbums = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .any, options: nil)
        userAlbums.enumerateObjects { (collection, _, _) in
            let assetCount = PHAsset.fetchAssets(in: collection, options: nil).count
            if assetCount > 0 {
                self.albums.append(collection)
            }
        }
        
        // Fetch smart albums
        let smartAlbums = PHAssetCollection.fetchAssetCollections(with: .smartAlbum, subtype: .any, options: nil)
        smartAlbums.enumerateObjects { (collection, _, _) in
            let assetCount = PHAsset.fetchAssets(in: collection, options: nil).count
            if assetCount > 0 {
                self.albums.append(collection)
            }
        }
        
        tableView.reloadData()
    }
    
    // MARK: - Actions
    @objc private func cancelTapped() {
        dismiss(animated: true)
    }
    
    // MARK: - UITableViewDataSource
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return section == 0 ? 1 : albums.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "AlbumCell", for: indexPath) as! AlbumCell
        
        if indexPath.section == 0 {
            // "All Photos" option
            cell.titleLabel.text = "All Photos"
            
            // Get total photo count
            let options = PHFetchOptions()
            options.predicate = NSPredicate(format: "mediaType == %d", PHAssetMediaType.image.rawValue)
            let allPhotos = PHAsset.fetchAssets(with: options)
            cell.countLabel.text = "\(allPhotos.count)"
        } else {
            // Album option
            let album = albums[indexPath.row]
            cell.titleLabel.text = album.localizedTitle ?? "Untitled"
            
            // Get album photo count
            let assetCount = PHAsset.fetchAssets(in: album, options: nil).count
            cell.countLabel.text = "\(assetCount)"
        }
        
        return cell
    }
    
    // MARK: - UITableViewDelegate
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        if indexPath.section == 0 {
            // "All Photos" selected
            delegate?.albumPicker(self, didSelectCollection: nil)
        } else {
            // Album selected
            let album = albums[indexPath.row]
            delegate?.albumPicker(self, didSelectCollection: album)
        }
        
        dismiss(animated: true)
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return section == 0 ? nil : "Albums"
    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 60
    }
}

// MARK: - AlbumCell
class AlbumCell: UITableViewCell {
    
    // MARK: - UI Elements
    let titleLabel = UILabel()
    let countLabel = UILabel()
    
    // MARK: - Initialization
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }
    
    // MARK: - Setup
    private func setupView() {
        // Cell appearance
        backgroundColor = .black
        selectionStyle = .default
        
        // Title label
        titleLabel.textColor = .white
        titleLabel.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        contentView.addSubview(titleLabel)
        
        // Count label
        countLabel.textColor = UIColor(white: 0.7, alpha: 1.0)
        countLabel.font = UIFont.systemFont(ofSize: 14)
        contentView.addSubview(countLabel)
        
        // Layout
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        countLabel.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            titleLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            
            countLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            countLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor)
        ])
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        titleLabel.text = nil
        countLabel.text = nil
    }
}
