//
//  HomeSubscribingPostsTableViewCell.swift
//  piction-ios
//
//  Created by jhseo on 2019/12/19.
//  Copyright © 2019 Piction Network. All rights reserved.
//

import UIKit
import PictionSDK

final class HomeSubscribingPostsTableViewCell: ReuseTableViewCell {
    @IBOutlet weak var largeThumbnailImageView: UIImageView!
    @IBOutlet weak var smallThumbnailImageView: UIImageView!
    @IBOutlet weak var projectLabel: UILabel!
    @IBOutlet weak var postLabel: UILabel!
    @IBOutlet weak var contentContainerView: UIView!
    @IBOutlet weak var contentLabel: UILabel!
    @IBOutlet weak var writerLabel: UILabel!
    @IBOutlet weak var publishedAtLabel: UILabel!

    typealias Model = SponsoringPostModel

    override func prepareForReuse() {
        super.prepareForReuse()
        largeThumbnailImageView.sd_cancelCurrentImageLoad()
        largeThumbnailImageView.image = #imageLiteral(resourceName: "img-dummy-post-960-x-360")
        smallThumbnailImageView.sd_cancelCurrentImageLoad()
        smallThumbnailImageView.image = #imageLiteral(resourceName: "img-dummy-post-960-x-360")
    }

    func configure(with model: Model) {
        let (categories, thumbnail, projectName, seriesName, postName, content, writerName, publishedAt) = (model.project?.categories, model.cover, model.project?.title, model.series?.name, model.title, model.previewText, model.project?.user?.username, model.publishedAt)

        var isLargeType: Bool {
            guard thumbnail != nil else { return false }
            guard let categories = categories else { return false }
            guard (categories.filter { ($0.name ?? "") == "일러스트" || ($0.name ?? "") == "웹툰" || ($0.name ?? "") == "사진" || ($0.name ?? "") == "영상" }.count) > 0 else { return false }
            return true
        }

        largeThumbnailImageView.isHidden = !isLargeType
        smallThumbnailImageView.isHidden = isLargeType || thumbnail == nil

        contentContainerView.isHidden = isLargeType || content?.isEmpty ?? true
        contentLabel.text = content

        if let thumbnail = thumbnail {
            let coverImageWithIC = "\(thumbnail)?w=656&h=656&quality=80&output=webp"
            if let url = URL(string: coverImageWithIC) {
                if isLargeType {
                    largeThumbnailImageView.sd_setImageWithFade(with: url, placeholderImage: #imageLiteral(resourceName: "img-dummy-post-960-x-360"), completed: nil)
                } else {
                    smallThumbnailImageView.sd_setImageWithFade(with: url, placeholderImage: #imageLiteral(resourceName: "img-dummy-post-960-x-360"), completed: nil)
                }
            }
        }
        let series = seriesName != nil ? " ᐧ \(seriesName ?? "")" : ""
        projectLabel.text = "\(projectName ?? "")\(series)"
        postLabel.text = postName
        writerLabel.text = writerName

        var lashPublishedDateTime: String {
            let diff = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: (publishedAt ?? Date()), to: Date())

            if let year = diff.year, year > 0 {
                return LocalizationKey.str_post_update_n_year.localized(with: year)
            } else if let month = diff.month, month > 0 {
                return LocalizationKey.str_post_update_n_month.localized(with: month)
            } else if let day = diff.day, day > 0 {
                return LocalizationKey.str_post_update_n_day.localized(with: day)
            } else if let hour = diff.hour, hour > 0 {
                return LocalizationKey.str_post_update_n_hour.localized(with: hour)
            } else if let minute = diff.minute, minute > 0 {
                return LocalizationKey.str_post_update_n_minute.localized(with: minute)
            } else {
                return LocalizationKey.str_post_update_n_now.localized()
            }
        }

        publishedAtLabel.text = lashPublishedDateTime
    }
}
