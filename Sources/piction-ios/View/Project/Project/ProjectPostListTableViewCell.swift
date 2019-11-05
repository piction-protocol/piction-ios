//
//  ProjectPostListTableViewCell.swift
//  PictionView
//
//  Created by jhseo on 03/07/2019.
//  Copyright © 2019 Piction Network. All rights reserved.
//

import UIKit
import PictionSDK

final class ProjectPostListTableViewCell: ReuseTableViewCell {
    @IBOutlet weak var thumbnailView: UIView!
    @IBOutlet weak var thumbnailImageView: UIImageView!
    @IBOutlet weak var seriesLabel: UILabel!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var dateLabel: UILabel!
    @IBOutlet weak var likeStackView: UIStackView!
    @IBOutlet weak var likeLabel: UILabel!
    @IBOutlet weak var lockView: UIView!
    @IBOutlet weak var lockMessageLabel: UILabel!
    @IBOutlet weak var maskImage: VisualEffectView!

    typealias Model = PostModel

    override func layoutSubviews() {
        self.contentView.autoresizingMask = [.flexibleHeight]

        super.layoutSubviews()
    }

    func configure(with model: Model, isSubscribing: Bool) {
        let (thumbnail, seriesName, title, publishedAt, likeCount, fanPassId, status) = (model.cover, model.series?.name, model.title, model.publishedAt, model.likeCount, model.fanPass?.id, model.status)

        if let thumbnail = thumbnail {
            let coverImageWithIC = "\(thumbnail)?w=656&h=246&quality=80&output=webp"
            if let url = URL(string: coverImageWithIC) {
                thumbnailImageView.sd_setImageWithFade(with: url, placeholderImage: #imageLiteral(resourceName: "img-dummy-post-960-x-360"), completed: nil)
            }
        } else {
            thumbnailImageView.image = #imageLiteral(resourceName: "img-dummy-post-960-x-360")
        }
        seriesLabel.isHidden = seriesName == nil
        seriesLabel.text = "\(LocalizedStrings.tab_series.localized()) · \(seriesName ?? "")"

        titleLabel.text = title

        if let publishedAt = publishedAt {
            if publishedAt.millisecondsSince1970 > Date().millisecondsSince1970 {
                dateLabel.text = publishedAt.toString(format: LocalizedStrings.str_reservation_datetime_format.localized())
            } else {
                dateLabel.text = publishedAt.toString(format: LocalizedStrings.str_date_format.localized())
            }
        }

        likeStackView.isHidden = (likeCount ?? 0) == 0
        likeLabel.text = "\(likeCount ?? 0)"

        if status == "PRIVATE" {
            lockMessageLabel.text = LocalizedStrings.str_private_only.localized()
            thumbnailView.isHidden = false
            maskImage.isHidden = false
            lockView.isHidden = false
            maskImage.blurRadius = thumbnail == nil ? 0 : 5
            lockView.backgroundColor = thumbnail == nil ? UIColor(r: 51, g: 51, b: 51, a: 0.2) : .clear
        } else {
            if (fanPassId != nil) && !isSubscribing {
                lockMessageLabel.text = LocalizedStrings.str_subs_only.localized()
                thumbnailView.isHidden = false
                maskImage.isHidden = false
                lockView.isHidden = false
                maskImage.blurRadius = thumbnail == nil ? 0 : 5
                lockView.backgroundColor = thumbnail == nil ? UIColor(r: 51, g: 51, b: 51, a: 0.2) : .clear
            } else {
                thumbnailView.isHidden = thumbnail == nil
                maskImage.isHidden = true
                lockView.isHidden = true
            }
        }
    }
}
