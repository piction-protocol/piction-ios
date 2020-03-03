//
//  ProjectPostListTypeListTableViewCell.swift
//  piction-ios
//
//  Created by jhseo on 2020/02/18.
//  Copyright © 2020 Piction Network. All rights reserved.
//

import UIKit
import PictionSDK

final class ProjectPostListTypeListTableViewCell: ReuseTableViewCell {
    @IBOutlet weak var thumbnailView: UIView!
    @IBOutlet weak var thumbnailImageView: UIImageView!
    @IBOutlet weak var seriesLabel: UILabel!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var dateLabel: UILabel!
    @IBOutlet weak var likeStackView: UIStackView!
    @IBOutlet weak var likeLabel: UILabel!
    @IBOutlet weak var lockView: UIView!
    @IBOutlet weak var maskImage: VisualEffectView!
    @IBOutlet weak var leftLockView: UIView!

    override func prepareForReuse() {
        super.prepareForReuse()
        thumbnailImageView.sd_cancelCurrentImageLoad()
        thumbnailImageView.image = #imageLiteral(resourceName: "img-dummy-post-960-x-360")
    }

    override func layoutSubviews() {
        self.contentView.autoresizingMask = [.flexibleHeight]
        super.layoutSubviews()
    }

    func configure(post: PostModel, subscriptionInfo: SponsorshipModel?, isWriter: Bool) {
        let (thumbnail, seriesName, title, publishedAt, likeCount, membership, status) = (post.cover, post.series?.name, post.title, post.publishedAt, post.likeCount, post.membership, post.status)

        if let thumbnail = thumbnail {
            thumbnailImageView.isHidden = false
            thumbnailView.backgroundColor = .pictionLightGray
            let coverImageWithIC = "\(thumbnail)?w=656&h=246&quality=80&output=webp"
            if let url = URL(string: coverImageWithIC) {
                thumbnailImageView.sd_setImageWithFade(with: url, placeholderImage: #imageLiteral(resourceName: "img-dummy-post-960-x-360"), completed: nil)
            }
        } else {
            thumbnailImageView.isHidden = true
            thumbnailView.backgroundColor = .clear
        }

        seriesLabel.isHidden = seriesName == nil
        seriesLabel.text = seriesName

        titleLabel.text = title

        if let publishedAt = publishedAt {
            if publishedAt.millisecondsSince1970 > Date().millisecondsSince1970 {
                dateLabel.text = publishedAt.toString(format: LocalizationKey.str_reservation_datetime_format.localized())
            } else {
                dateLabel.text = publishedAt.toString(format: LocalizationKey.str_date_format.localized())
            }
        }

        likeStackView.isHidden = (likeCount ?? 0) == 0
        likeLabel.text = "\(likeCount ?? 0)"

        if status == "PRIVATE" {
            thumbnailView.isHidden = thumbnail == nil
            maskImage.isHidden = true
            lockView.isHidden = true
            maskImage.blurRadius = 0
            lockView.backgroundColor = .clear
        } else {
            var needSubscription: Bool {
                if isWriter {
                    return false
                }
                if membership == nil {
                    return false
                }
                if (membership?.level != nil) && (subscriptionInfo?.membership?.level == nil) {
                    return true
                }
                if (membership?.level ?? 0) <= (subscriptionInfo?.membership?.level ?? 0) {
                    return false
                }
                return true
            }

            if needSubscription {
                thumbnailView.isHidden = thumbnail == nil
                maskImage.isHidden = thumbnail == nil
                lockView.isHidden = thumbnail == nil
                leftLockView.isHidden = thumbnail != nil

                maskImage.blurRadius = thumbnail == nil ? 0 : 5
                lockView.backgroundColor = thumbnail == nil ? UIColor(r: 51, g: 51, b: 51, a: 0.2) : .clear
            } else {
                thumbnailView.isHidden = thumbnail == nil
                leftLockView.isHidden = true
                maskImage.isHidden = true
                lockView.isHidden = true
            }
        }
    }
}
