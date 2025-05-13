//
//  ProfileSettingsViewDelegate.swift
//  InstaFeed
//
//  Created by Dan Chernopolskii on 5/7/25.
//

import UIKit
import Photos

protocol ProfileSettingsViewDelegate: AnyObject {
    func profileSettingsView(_ view: ProfileSettingsView, didUpdateUsername username: String)
    func profileSettingsView(_ view: ProfileSettingsView, didSelectProfileImage image: UIImage?)
}

class ProfileSettingsView: UIView {
    
    // MARK: - UI Elements
    private let profileImageView = UIImageView()
    private let usernameField = UITextField()
    private let editImageButton = UIButton(type: .system)
    
    // MARK: - Properties
    weak var delegate: ProfileSettingsViewDelegate?
    var username: String = "yourusername" {
        didSet {
            usernameField.text = username
        }
    }
    
    // MARK: - Initialization
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }
    
    // MARK: - Setup
    private func setupView() {
        backgroundColor = UIColor(white: 0.1, alpha: 1.0)
        
        // Profile image
        profileImageView.contentMode = .scaleAspectFill
        profileImageView.backgroundColor = UIColor(white: 0.2, alpha: 1.0)
        profileImageView.layer.cornerRadius = 40
        profileImageView.clipsToBounds = true
        profileImageView.image = UIImage(systemName: "person.crop.circle.fill")
        profileImageView.tintColor = .white
        addSubview(profileImageView)
        
        // Edit button overlay
        editImageButton.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        editImageButton.setImage(UIImage(systemName: "camera.fill"), for: .normal)
        editImageButton.tintColor = .white
        editImageButton.layer.cornerRadius = 15
        editImageButton.addTarget(self, action: #selector(editImageTapped), for: .touchUpInside)
        addSubview(editImageButton)
        
        // Username field
        usernameField.backgroundColor = UIColor(white: 0.15, alpha: 1.0)
        usernameField.textColor = .white
        usernameField.placeholder = "Your Instagram username"
        usernameField.font = UIFont.systemFont(ofSize: 15, weight: .medium)
        usernameField.borderStyle = .roundedRect
        usernameField.clearButtonMode = .whileEditing
        usernameField.returnKeyType = .done
        usernameField.delegate = self
        usernameField.text = username
        addSubview(usernameField)
        
        // Set constraints
        profileImageView.translatesAutoresizingMaskIntoConstraints = false
        editImageButton.translatesAutoresizingMaskIntoConstraints = false
        usernameField.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            profileImageView.topAnchor.constraint(equalTo: topAnchor, constant: 16),
            profileImageView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            profileImageView.widthAnchor.constraint(equalToConstant: 80),
            profileImageView.heightAnchor.constraint(equalToConstant: 80),
            profileImageView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -16),
            
            editImageButton.trailingAnchor.constraint(equalTo: profileImageView.trailingAnchor),
            editImageButton.bottomAnchor.constraint(equalTo: profileImageView.bottomAnchor),
            editImageButton.widthAnchor.constraint(equalToConstant: 30),
            editImageButton.heightAnchor.constraint(equalToConstant: 30),
            
            usernameField.leadingAnchor.constraint(equalTo: profileImageView.trailingAnchor, constant: 16),
            usernameField.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            usernameField.centerYAnchor.constraint(equalTo: profileImageView.centerYAnchor),
            usernameField.heightAnchor.constraint(equalToConstant: 40)
        ])
    }
    
    // MARK: - Actions
    @objc private func editImageTapped() {
        delegate?.profileSettingsView(self, didSelectProfileImage: profileImageView.image)
    }
    
    // MARK: - Public Methods
    func setProfileImage(_ image: UIImage?) {
        if let image = image {
            profileImageView.image = image
            profileImageView.contentMode = .scaleAspectFill
        } else {
            profileImageView.image = UIImage(systemName: "person.crop.circle.fill")
            profileImageView.contentMode = .scaleAspectFit
            profileImageView.tintColor = .white
        }
    }
}

// MARK: - UITextFieldDelegate
extension ProfileSettingsView: UITextFieldDelegate {
    func textFieldDidEndEditing(_ textField: UITextField) {
        if let text = textField.text, !text.isEmpty {
            username = text
            delegate?.profileSettingsView(self, didUpdateUsername: text)
        }
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
}
