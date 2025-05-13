//
//  FloatingButtonsView.swift
//  InstaFeed
//
//  Created by Dan Chernopolskii on 5/8/25.
//


import UIKit

protocol FloatingButtonsDelegate: AnyObject {
    func floatingButtonsDidTapSettings(_ view: FloatingButtonsView)
    func floatingButtonsDidTapColor(_ view: FloatingButtonsView)
    func floatingButtonsDidLongPressColor(_ view: FloatingButtonsView, at point: CGPoint, with gestureRecognizer: UILongPressGestureRecognizer)
    func floatingButtonsDidTapFolder(_ view: FloatingButtonsView)
}

class FloatingButtonsView: UIView {
    
    // MARK: - UI Elements
    public let settingsButton = UIButton(type: .system)
    public let colorButton = UIButton(type: .custom)
    public let folderButton = UIButton(type: .system)
    
    // MARK: - Properties
    weak var delegate: FloatingButtonsDelegate?
    
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
        backgroundColor = .clear
        
        // Setup settings button
        settingsButton.setImage(UIImage(systemName: "gear"), for: .normal)
        settingsButton.tintColor = .white
        settingsButton.backgroundColor = UIColor(white: 0.15, alpha: 1.0)
        settingsButton.layer.cornerRadius = 22
        addFloatingShadow(to: settingsButton)
        settingsButton.addTarget(self, action: #selector(settingsButtonTapped), for: .touchUpInside)
        
        // Setup color button
        colorButton.backgroundColor = .purple
        colorButton.layer.cornerRadius = 32
        colorButton.layer.borderWidth = 2
        colorButton.layer.borderColor = UIColor.white.cgColor
        addFloatingShadow(to: colorButton)
        
        // Add color icon
        let colorIcon = UIImage(systemName: "circle.hexagongrid.fill")?.withRenderingMode(.alwaysTemplate)
        colorButton.setImage(colorIcon, for: .normal)
        colorButton.tintColor = .white
        colorButton.addTarget(self, action: #selector(colorButtonTapped), for: .touchUpInside)
        
        // Add long press for color wheel
        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(handleColorButtonLongPress(_:)))
        longPress.minimumPressDuration = 0.3
        colorButton.addGestureRecognizer(longPress)
        
        // Setup folder button
        folderButton.setImage(UIImage(systemName: "folder"), for: .normal)
        folderButton.tintColor = .white
        folderButton.backgroundColor = UIColor(white: 0.15, alpha: 1.0)
        folderButton.layer.cornerRadius = 22
        addFloatingShadow(to: folderButton)
        folderButton.addTarget(self, action: #selector(folderButtonTapped), for: .touchUpInside)
        
        // Add buttons to view
        addSubview(settingsButton)
        addSubview(colorButton)
        addSubview(folderButton)
        
        // Setup layout
        setupConstraints()
    }
    
    private func setupConstraints() {
        settingsButton.translatesAutoresizingMaskIntoConstraints = false
        colorButton.translatesAutoresizingMaskIntoConstraints = false
        folderButton.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            // Settings button
            settingsButton.leadingAnchor.constraint(equalTo: leadingAnchor),
            settingsButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            settingsButton.widthAnchor.constraint(equalToConstant: 44),
            settingsButton.heightAnchor.constraint(equalToConstant: 44),
            
            // Color button
            colorButton.centerXAnchor.constraint(equalTo: centerXAnchor),
            colorButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            colorButton.widthAnchor.constraint(equalToConstant: 64),
            colorButton.heightAnchor.constraint(equalToConstant: 64),
            
            // Folder button
            folderButton.trailingAnchor.constraint(equalTo: trailingAnchor),
            folderButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            folderButton.widthAnchor.constraint(equalToConstant: 44),
            folderButton.heightAnchor.constraint(equalToConstant: 44)
        ])
    }
    
    private func addFloatingShadow(to view: UIView) {
        view.layer.shadowColor = UIColor.black.cgColor
        view.layer.shadowOpacity = 0.5
        view.layer.shadowOffset = CGSize(width: 0, height: 3)
        view.layer.shadowRadius = 5
    }
    
    // MARK: - Public Methods
    func setColorButtonColor(_ color: UIColor) {
        colorButton.backgroundColor = color
    }
    
    // MARK: - Actions
    @objc private func settingsButtonTapped() {
        delegate?.floatingButtonsDidTapSettings(self)
    }
    
    @objc private func colorButtonTapped() {
        delegate?.floatingButtonsDidTapColor(self)
    }
    
    @objc private func handleColorButtonLongPress(_ gesture: UILongPressGestureRecognizer) {
        let point = gesture.location(in: self)
        delegate?.floatingButtonsDidLongPressColor(self, at: point, with: gesture)
    }
    
    @objc private func folderButtonTapped() {
        delegate?.floatingButtonsDidTapFolder(self)
    }
}
