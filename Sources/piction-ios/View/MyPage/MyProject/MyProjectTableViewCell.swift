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
    @IBOutlet weak var statusLabel: UILabel!
    @IBOutlet weak var lockView: UIView!
    @IBOutlet weak var maskImage: VisualEffectView! {
        didSet {
            maskImage.blurRadius = 5
        }
    }

    typealias Model = ProjectModel

    func configure(with model: Model) {
        let (wideThumbnail, title, subscriptionUserCount, status) = (model.wideThumbnail, model.title, model.subscriptionUserCount, model.status)

        if let wideThumbnail = wideThumbnail {
            let wideThumbnailWithIC = "\(wideThumbnail)?w=720&h=360&quality=80&output=webp"
            if let url = URL(string: wideThumbnailWithIC) {
                thumbnailImageView.sd_setImageWithFade(with: url, placeholderImage: #imageLiteral(resourceName: "img-dummy-projectcover-1440-x-450"), completed: nil)
            }
        } else {
            thumbnailImageView.image = #imageLiteral(resourceName: "img-dummy-projectcover-1440-x-450")
        }

        titleLabel.text = title
        subscriptionCountLabel.text = LocalizedStrings.str_subs_count_plural.localized(with: subscriptionUserCount ?? 0)

        if status == "HIDDEN" || status == "DEPRECATED" {
            lockView.isHidden = false
            maskImage.isHidden = false
            if status == "HIDDEN" {
                statusLabel.text = "비공개"
            } else if status == "DEPRECATED" {
                statusLabel.text = "부적절한 컨텐츠"
            }
        } else {
            lockView.isHidden = true
            maskImage.isHidden = true
        }
    }
}
