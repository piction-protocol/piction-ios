//
//  MyProjectTableViewCell.swift
//  PictionView
//
//  Created by jhseo on 12/07/2019.
//  Copyright © 2019 Piction Network. All rights reserved.
//

import UIKit
import PictionSDK

final class MyProjectTableViewCell: ReuseTableViewCell {
    @IBOutlet weak var thumbnailImageView: UIImageView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var subscriptionCountLabel: UILabel!

    typealias Model = ProjectModel

    func configure(with model: Model) {
        let (wideThumbnail, title, subscriptionCount) = (model.wideThumbnail, model.title, model.subscriptionUserCount)

        let wideThumbnailWithIC = "\(wideThumbnail ?? "")?w=720&h=360&quality=80&output=webp"
        if let url = URL(string: wideThumbnailWithIC) {
            thumbnailImageView.sd_setImageWithFade(with: url, placeholderImage: #imageLiteral(resourceName: "img-dummy-projectcover-1440-x-450"), completed: nil)
        } else {
            thumbnailImageView.image = #imageLiteral(resourceName: "img-dummy-projectcover-1440-x-450")
        }

        titleLabel.text = title
        subscriptionCountLabel.text = "구독자 수 \(subscriptionCount ?? 0)"
    }
}
