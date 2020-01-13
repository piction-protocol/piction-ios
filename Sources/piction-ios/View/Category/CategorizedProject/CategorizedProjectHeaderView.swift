//
//  CategorizedProjectHeaderView.swift
//  piction-ios
//
//  Created by jhseo on 2020/01/09.
//  Copyright © 2019 Piction Network. All rights reserved.
//

import Foundation
import PictionSDK
import GSKStretchyHeaderView

class CategorizedProjectHeaderView: GSKStretchyHeaderView {
    @IBOutlet weak var coverImageView: UIImageView! {
        didSet {
            let gradientLayer = CAGradientLayer()
            let color1 = UIColor(white: 0.0, alpha: 0.38).cgColor
            let color2 = UIColor.clear.cgColor
            gradientLayer.colors = [color1, color2]
            gradientLayer.locations = [0.0, 1.0]
            gradientLayer.frame = CGRect(x: 0, y: 0, width: SCREEN_H, height: SCREEN_W / 3)
            coverImageView.layer.addSublayer(gradientLayer)
        }
    }
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var projectCountLabel: UILabel!

    @IBOutlet weak var maskImage: VisualEffectView!
    @IBOutlet weak var naviView: UIView!
    @IBOutlet var naviViewImageHeight: NSLayoutConstraint!

    override func awakeFromNib() {
        super.awakeFromNib()
        minimumContentHeight = STATUS_HEIGHT + DEFAULT_NAVIGATION_HEIGHT
        maximumContentHeight = self.frame.size.width / 2 - STATUS_HEIGHT - DEFAULT_NAVIGATION_HEIGHT
        naviViewImageHeight.constant = STATUS_HEIGHT + DEFAULT_NAVIGATION_HEIGHT

        expansionMode = .topOnly

        coverImageView.contentMode = .scaleAspectFill
    }

    func configureCategoryInfo(with model: CategoryModel) {
        let (thumbnail, title, categorizedCount) = (model.thumbnail, model.name, model.categorizedCount)

        if let coverImage = thumbnail {
            let coverImageWithIC = "\(coverImage)?w=656&h=246&quality=80&output=webp"
            if let url = URL(string: coverImageWithIC) {
                coverImageView.sd_setImageWithFade(with: url, placeholderImage: UIImage())
            }
        } else {
            coverImageView.image = nil
        }

        titleLabel.text = title
        projectCountLabel.text = LocalizedStrings.str_projects_count.localized(with: categorizedCount.commaRepresentation)
    }
}

extension CategorizedProjectHeaderView {
    static func getView() -> CategorizedProjectHeaderView {
        let view = Bundle.main.loadNibNamed("CategorizedProjectHeaderView", owner: self, options: nil)!.first as! CategorizedProjectHeaderView
        return view
    }
}
