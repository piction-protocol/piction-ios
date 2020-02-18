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
    @IBOutlet weak var sponsorCountLabel: UILabel!
    @IBOutlet weak var statusLabel: UILabel!
    @IBOutlet weak var lockView: UIView!
    @IBOutlet weak var maskImage: VisualEffectView! {
        didSet {
            maskImage.blurRadius = 5
        }
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        thumbnailImageView.sd_cancelCurrentImageLoad()
        thumbnailImageView.image = #imageLiteral(resourceName: "img-dummy-projectcover-1440-x-450")
    }

    typealias Model = ProjectModel

    func configure(with model: Model) {
        let (wideThumbnail, title, sponsorCount, status) = (model.wideThumbnail, model.title, model.sponsorCount, model.status)

        if let wideThumbnail = wideThumbnail {
            let wideThumbnailWithIC = "\(wideThumbnail)?w=720&h=360&quality=80&output=webp"
            if let url = URL(string: wideThumbnailWithIC) {
                thumbnailImageView.sd_setImageWithFade(with: url, placeholderImage: #imageLiteral(resourceName: "img-dummy-projectcover-1440-x-450"), completed: nil)
            }
        }

        titleLabel.text = title
        sponsorCountLabel.text = LocalizationKey.str_subs_count_plural.localized(with: sponsorCount?.commaRepresentation ?? "0")

        if status == "HIDDEN" || status == "DEPRECATED" {
            lockView.isHidden = false
            maskImage.isHidden = false
            if status == "HIDDEN" {
                statusLabel.text = LocalizationKey.str_post_status_private.localized()
            } else if status == "DEPRECATED" {
                statusLabel.text = LocalizationKey.str_post_status_deprecated.localized()
            }
        } else {
            lockView.isHidden = true
            maskImage.isHidden = true
        }
    }
}
