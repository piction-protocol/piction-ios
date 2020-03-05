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

// MARK: - GSKStretchyHeaderView
class CategorizedProjectHeaderView: GSKStretchyHeaderView {
    @IBOutlet weak var coverImageView: UIImageView! {
        didSet {
            // 그라데이션 효과
            let gradientLayer = CAGradientLayer()
            let color1 = UIColor(white: 0.0, alpha: 0.38).cgColor
            let color2 = UIColor.clear.cgColor
            gradientLayer.colors = [color1, color2]
            gradientLayer.locations = [0.0, 1.0]
            let width = SCREEN_W > SCREEN_H ? SCREEN_W : SCREEN_H
            gradientLayer.frame = CGRect(x: 0, y: 0, width: width, height: SCREEN_W / 3)
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
        let width = SCREEN_W < SCREEN_H ? SCREEN_W : SCREEN_H

        // GSKStretchyHeaderView 설정
        minimumContentHeight = STATUS_HEIGHT + DEFAULT_NAVIGATION_HEIGHT
        maximumContentHeight = width / 2 - STATUS_HEIGHT - DEFAULT_NAVIGATION_HEIGHT
        expansionMode = .topOnly

        naviViewImageHeight.constant = STATUS_HEIGHT + DEFAULT_NAVIGATION_HEIGHT
        coverImageView.contentMode = .scaleAspectFill
    }
}
// MARK: - Public Method
extension CategorizedProjectHeaderView {
    // 카테고리 정보를 가져와서 설정
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
        projectCountLabel.text = LocalizationKey.str_projects_count.localized(with: categorizedCount.commaRepresentation)
    }
}

// MARK: - Static Method
extension CategorizedProjectHeaderView {
    static func getView() -> CategorizedProjectHeaderView {
        let view = Bundle.main.loadNibNamed("CategorizedProjectHeaderView", owner: self, options: nil)!.first as! CategorizedProjectHeaderView
        return view
    }
}
