//
//  UILabel+Extension.swift
//  piction-ios
//
//  Created by jhseo on 18/10/2019.
//  Copyright © 2017년 thewhalegames. All rights reserved.
//

import UIKit

@IBDesignable
class UILabelExtension: UILabel, BorderLineConfigurable {

    // MARK: - Initializations
    override init(frame: CGRect) {
        super.init(frame: frame)
        configure()
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        configure()
    }

    // MARK: - BorderLineConfigurable
    @IBInspectable
    var borderColor: UIColor = UIColor.clear {
        didSet {
            layer.borderColor = borderColor.cgColor
        }
    }

    @IBInspectable
    var borderWidth: CGFloat = 1.0 {
        didSet {
            layer.borderWidth = borderWidth
        }
    }

    @IBInspectable
    var cornerRadius: CGFloat = 0.0 {
        didSet {
            configureRadius()
        }
    }

    @IBInspectable
    var topLeftRadius: Bool = false {
        didSet {
            configureRadius()
        }
    }

    @IBInspectable
    var topRightRadius: Bool = false {
        didSet {
            configureRadius()
        }
    }

    @IBInspectable
    var bottomLeftRadius: Bool = false {
        didSet {
            configureRadius()
        }
    }

    @IBInspectable
    var bottomRightRadius: Bool = false {
        didSet {
            configureRadius()
        }
    }

    @IBInspectable
    var letterSpacing: CGFloat = 1.0 {
        didSet {
            let attributedStr = self.attributedText?.mutableCopy() as! NSMutableAttributedString
            attributedStr.addAttribute(NSAttributedString.Key.kern, value: letterSpacing, range: NSRange(location: 0, length: attributedStr.length))
            self.attributedText = attributedStr
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        configureRadius()
    }

    // MARK: - private method
    private func configure() {
        layer.borderColor = borderColor.cgColor
        layer.borderWidth = borderWidth
        configureRadius()
    }

    private func configureRadius() {
        guard cornerRadius > 0 else { return }
        guard topLeftRadius || topRightRadius || bottomLeftRadius || bottomRightRadius else {
            layer.cornerRadius = cornerRadius
            layer.masksToBounds = cornerRadius > 0
            return
        }

        var corners = UIRectCorner()
        if topLeftRadius {
            corners.insert(.topLeft)
        }
        if topRightRadius {
            corners.insert(.topRight)
        }
        if bottomLeftRadius {
            corners.insert(.bottomLeft)
        }
        if bottomRightRadius {
            corners.insert(.bottomRight)
        }

        let path = UIBezierPath(roundedRect: self.bounds, byRoundingCorners: corners, cornerRadii: CGSize(width: cornerRadius, height: cornerRadius))
        let mask = CAShapeLayer()
        mask.path = path.cgPath
        layer.mask = mask
        layer.masksToBounds = cornerRadius > 0
    }
}
