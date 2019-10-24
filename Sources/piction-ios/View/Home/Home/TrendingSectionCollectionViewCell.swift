//
//  TrendingSectionCollectionViewCell.swift
//  piction-ios
//
//  Created by jhseo on 17/10/2019.
//  Copyright © 2019 Piction Network. All rights reserved.
//

import UIKit
import PictionSDK

final class TrendingSectionCollectionViewCell: ReuseCollectionViewCell {
    @IBOutlet weak var thumbnailImageView: UIImageView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var subscriptionCountLabel: UILabel!

    typealias Model = ProjectModel

    func configure(with model: Model) {
        let (thumbnail, title, subscriptionUserCount) = (model.thumbnail, model.title,  model.subscriptionUserCount)
//
        let thumbnailWithIC = "\(thumbnail ?? "")?w=720&h=720&quality=80&output=webp"
        if let url = URL(string: thumbnailWithIC) {
            thumbnailImageView.sd_setImageWithFade(with: url, placeholderImage: #imageLiteral(resourceName: "img-dummy-square-500-x-500"), completed: nil)
        } else {
            thumbnailImageView.image = #imageLiteral(resourceName: "img-dummy-square-500-x-500")
        }
//
        titleLabel.text = title
        subscriptionCountLabel.text = LocalizedStrings.str_subs_count_plural.localized(with: subscriptionUserCount ?? 0)

    }
}
