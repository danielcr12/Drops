//
//  Drops
//
//  Copyright (c) 2021-Present Omar Albeik - https://github.com/omaralbeik
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.

#if os(iOS) || os(visionOS)
import UIKit

internal final class DropView: UIView {
  required init(drop: Drop) {
    self.drop = drop
    super.init(frame: .zero)

    if #available(iOS 26.0, *) {
      // iOS 26+: Glass background, no extra shadows/rasterization from us.
      isOpaque = false
      backgroundColor = .clear
      layer.allowsGroupOpacity = false

      insertSubview(glassBackgroundView, at: 0)
      NSLayoutConstraint.activate([
        glassBackgroundView.leadingAnchor.constraint(equalTo: leadingAnchor),
        glassBackgroundView.trailingAnchor.constraint(equalTo: trailingAnchor),
        glassBackgroundView.topAnchor.constraint(equalTo: topAnchor),
        glassBackgroundView.bottomAnchor.constraint(equalTo: bottomAnchor)
      ])

      // Optional glass tint overlay if provided.
      if let tint = drop.glassTintColor {
        glassBackgroundView.contentView.addSubview(glassTintOverlay)
        glassTintOverlay.backgroundColor = tint.withAlphaComponent(Self.glassTintAlpha)
        NSLayoutConstraint.activate([
          glassTintOverlay.leadingAnchor.constraint(equalTo: glassBackgroundView.contentView.leadingAnchor),
          glassTintOverlay.trailingAnchor.constraint(equalTo: glassBackgroundView.contentView.trailingAnchor),
          glassTintOverlay.topAnchor.constraint(equalTo: glassBackgroundView.contentView.topAnchor),
          glassTintOverlay.bottomAnchor.constraint(equalTo: glassBackgroundView.contentView.bottomAnchor)
        ])
      }
    } else {
      // Older iOS: Solid background.
      backgroundColor = .secondarySystemBackground
    }

    addSubview(stackView)

    let constraints = createLayoutConstraints(for: drop)
    NSLayoutConstraint.activate(constraints)
    configureViews(for: drop)
  }

  required init?(coder _: NSCoder) {
    return nil
  }

  override var frame: CGRect {
    didSet {
      if #available(iOS 26.0, *) {
        // No main-layer shaping on iOS 26+; glass view gets shaped in layoutSubviews.
      } else {
        layer.cornerRadius = frame.cornerRadius
      }
    }
  }

  override var bounds: CGRect {
    didSet {
      if #available(iOS 26.0, *) {
        // No main-layer shaping on iOS 26+; glass view gets shaped in layoutSubviews.
      } else {
        layer.cornerRadius = frame.cornerRadius
      }
    }
  }

  override func layoutSubviews() {
    super.layoutSubviews()

    if #available(iOS 26.0, *) {
      // Keep capsule shape by clipping the effect view (and its tint overlay) to a pill.
      let radius = bounds.height / 2
      glassBackgroundView.layer.masksToBounds = true
      glassBackgroundView.layer.cornerCurve = .continuous
      glassBackgroundView.layer.cornerRadius = radius

      if glassTintOverlay.superview != nil {
        glassTintOverlay.layer.masksToBounds = true
        glassTintOverlay.layer.cornerCurve = .continuous
        glassTintOverlay.layer.cornerRadius = radius
      }

      // No custom shadow path on iOS 26+.
      layer.shadowPath = nil
    } else {
      let radius = bounds.height / 2
      layer.shadowPath = UIBezierPath(roundedRect: bounds, cornerRadius: radius).cgPath
    }
  }

  let drop: Drop

  func createLayoutConstraints(for drop: Drop) -> [NSLayoutConstraint] {
    var constraints: [NSLayoutConstraint] = []

    constraints += [
      imageView.heightAnchor.constraint(equalToConstant: 25),
      imageView.widthAnchor.constraint(equalToConstant: 25)
    ]

    constraints += [
      button.heightAnchor.constraint(equalToConstant: 35),
      button.widthAnchor.constraint(equalToConstant: 35)
    ]

    var insets = UIEdgeInsets(top: 7.5, left: 12.5, bottom: 7.5, right: 12.5)

    if drop.icon == nil {
      insets.left = 40
    }

    if drop.action?.icon == nil {
      insets.right = 40
    }

    if drop.subtitle == nil {
      insets.top = 15
      insets.bottom = 15
      if drop.action?.icon != nil {
        insets.top = 10
        insets.bottom = 10
        insets.right = 10
      }
    }

    if drop.icon == nil, drop.action?.icon == nil {
      insets.left = 50
      insets.right = 50
    }

    constraints += [
      stackView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: insets.left),
      stackView.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor, constant: insets.top),
      stackView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -insets.right),
      stackView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -insets.bottom)
    ]

    return constraints
  }

  func configureViews(for drop: Drop) {
    // On iOS 26+, let the system glass handle its own capsule; don't clip the container.
    if #available(iOS 26.0, *) {
      clipsToBounds = false
    } else {
      clipsToBounds = true
    }

    titleLabel.text = drop.title
    titleLabel.numberOfLines = drop.titleNumberOfLines

    subtitleLabel.text = drop.subtitle
    subtitleLabel.numberOfLines = drop.subtitleNumberOfLines
    subtitleLabel.isHidden = drop.subtitle == nil

    // Icon tinting: prefer accentColor if provided; otherwise keep existing behavior.
    if let icon = drop.icon {
      if let accent = drop.accentColor {
        imageView.image = icon.withRenderingMode(.alwaysTemplate)
        imageView.tintColor = accent
      } else {
        imageView.image = icon
        imageView.tintColor = UIAccessibility.isDarkerSystemColorsEnabled ? .label : .secondaryLabel
      }
    } else {
      imageView.image = nil
    }
    imageView.isHidden = drop.icon == nil

    // Action button tinting: background uses accentColor if provided.
    button.setImage(drop.action?.icon, for: .normal)
    button.isHidden = drop.action?.icon == nil
    if let accent = drop.accentColor {
      button.backgroundColor = accent
      button.tintColor = .white // ensure contrast for symbol
    } else {
      button.backgroundColor = .link
      button.tintColor = .white
    }

    if let action = drop.action, action.icon == nil {
      let tap = UITapGestureRecognizer(target: self, action: #selector(didTapButton))
      addGestureRecognizer(tap)
    }

    if #available(iOS 26.0, *) {
      // Glass: disable our own shadows and rasterization to avoid artifacts and double effects.
      layer.shadowOpacity = 0
      layer.shadowRadius = 0
      layer.shadowOffset = .zero
      layer.shouldRasterize = false
      layer.masksToBounds = false

      // If Reduce Transparency is enabled, optionally fall back to solid background.
      if UIAccessibility.isReduceTransparencyEnabled {
        backgroundColor = .secondarySystemBackground
      }
    } else {
      // Solid background: keep the existing soft shadow with a defined path (set in layoutSubviews).
      layer.shadowColor = UIColor.black.cgColor
      layer.shadowOffset = .zero
      layer.shadowRadius = 25
      layer.shadowOpacity = 0.15
      layer.shouldRasterize = true
      #if os(iOS)
      layer.rasterizationScale = UIScreen.main.scale
      #endif
      layer.masksToBounds = false
    }
  }

  @objc
  func didTapButton() {
    drop.action?.handler()
  }

  // MARK: - Subviews

  lazy var titleLabel: UILabel = {
    let label = UILabel()
    label.translatesAutoresizingMaskIntoConstraints = false
    label.textAlignment = .center
    label.textColor = .label
    label.font = UIFont.preferredFont(forTextStyle: .subheadline).bold
    label.adjustsFontForContentSizeCategory = true
    label.adjustsFontSizeToFitWidth = true
    return label
  }()

  lazy var subtitleLabel: UILabel = {
    let label = UILabel()
    label.translatesAutoresizingMaskIntoConstraints = false
    label.textAlignment = .center
    label.textColor = UIAccessibility.isDarkerSystemColorsEnabled ? .label : .secondaryLabel
    label.font = UIFont.preferredFont(forTextStyle: .subheadline)
    label.adjustsFontForContentSizeCategory = true
    label.adjustsFontSizeToFitWidth = true
    return label
  }()

  lazy var imageView: UIImageView = {
    let view = RoundImageView()
    view.translatesAutoresizingMaskIntoConstraints = false
    view.contentMode = .scaleAspectFit
    view.clipsToBounds = true
    view.tintColor = UIAccessibility.isDarkerSystemColorsEnabled ? .label : .secondaryLabel
    return view
  }()

  lazy var button: UIButton = {
    let button = RoundButton(type: .system)
    button.translatesAutoresizingMaskIntoConstraints = false
    button.addTarget(self, action: #selector(didTapButton), for: .touchUpInside)
    button.clipsToBounds = true
    button.backgroundColor = .link
    button.tintColor = .white
    button.imageView?.contentMode = .scaleAspectFit
    button.contentEdgeInsets = .init(top: 7.5, left: 7.5, bottom: 7.5, right: 7.5)
    return button
  }()

  lazy var labelsStackView: UIStackView = {
    let view = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel])
    view.translatesAutoresizingMaskIntoConstraints = false
    view.axis = .vertical
    view.alignment = .fill
    view.distribution = .fill
    view.spacing = -1
    return view
  }()

  lazy var stackView: UIStackView = {
    let view = UIStackView(arrangedSubviews: [imageView, labelsStackView, button])
    view.translatesAutoresizingMaskIntoConstraints = false
    view.axis = .horizontal
    view.alignment = .center
    view.distribution = .fill
    if drop.icon != nil, drop.action?.icon != nil {
      view.spacing = 20
    } else {
      view.spacing = 15
    }
    return view
  }()

  // Background glass effect container (iOS 26+)
  private lazy var glassBackgroundView: UIVisualEffectView = {
    let effect: UIVisualEffect
    if #available(iOS 26.0, *) {
      effect = UIGlassEffect(style: .regular)
    } else {
      effect = UIBlurEffect(style: .systemThinMaterial)
    }
    let v = UIVisualEffectView(effect: effect)
    v.isOpaque = false
    v.backgroundColor = .clear
    v.translatesAutoresizingMaskIntoConstraints = false
    v.isUserInteractionEnabled = false
    return v
  }()

  // Optional tint overlay for glass (iOS 26+ when glassTintColor is provided)
  private lazy var glassTintOverlay: UIView = {
    let v = UIView()
    v.translatesAutoresizingMaskIntoConstraints = false
    v.isUserInteractionEnabled = false
    v.backgroundColor = .clear
    return v
  }()

  // MARK: - Constants

  private static let glassTintAlpha: CGFloat = 0.12
}

final class RoundButton: UIButton {
  override var bounds: CGRect {
    didSet { layer.cornerRadius = frame.cornerRadius }
  }
}

final class RoundImageView: UIImageView {
  override var bounds: CGRect {
    didSet { layer.cornerRadius = frame.cornerRadius }
  }
}

extension UIFont {
  var bold: UIFont {
    guard let descriptor = fontDescriptor.withSymbolicTraits(.traitBold) else { return self }
    return UIFont(descriptor: descriptor, size: pointSize)
  }
}

extension CGRect {
  var cornerRadius: CGFloat {
    return min(width, height) / 2
  }
}
#endif
