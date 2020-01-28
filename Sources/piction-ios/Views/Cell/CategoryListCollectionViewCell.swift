//
//  CategoryListCollectionViewCell.swift
//  piction-ios
//
//  Created by jhseo on 2020/01/08.
//  Copyright © 2019 Piction Network. All rights reserved.
//

import UIKit
import PictionSDK

final class CategoryListCollectionViewCell: ReuseCollectionViewCell {
    @IBOutlet weak var thumbnailImageView: UIImageView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var categorizedCountLabel: UILabel!
    @IBOutlet weak var thumbnailMaskView: UIView!

    override func prepareForReuse() {
        super.prepareForReuse()
        thumbnailImageView.sd_cancelCurrentImageLoad()
        thumbnailImageView.image = #imageLiteral(resourceName: "img-dummy-square-500-x-500")
    }

    typealias Model = CategoryModel

    func configure(with model: Model) {
        let (thumbnail, title, categorizedCount) = (model.thumbnail, model.name, model.categorizedCount)

        if let thumbnail = thumbnail {
            let thumbnailWithIC = "\(thumbnail)?w=328&h=160&quality=80&output=webp"
            if let url = URL(string: thumbnailWithIC) {
                thumbnailImageView.sd_setImageWithFade(with: url, placeholderImage: #imageLiteral(resourceName: "img-dummy-square-500-x-500"), completed: nil)
            }
        }

        titleLabel.text = title
        thumbnailMaskView.isHidden = title == nil
        categorizedCountLabel.isHidden = title == nil
        categorizedCountLabel.text = LocalizationKey.str_projects_count.localized(with: categorizedCount.commaRepresentation)
    }
}
