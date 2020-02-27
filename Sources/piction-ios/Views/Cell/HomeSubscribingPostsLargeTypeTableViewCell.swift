//
//  HomeSubscribingPostsLargeTypeTableViewCell.swift
//  piction-ios
//
//  Created by Junghoon on 2020/02/27.
//  Copyright © 2020 Piction Network. All rights reserved.
//

import UIKit
import PictionSDK

final class HomeSubscribingPostsLargeTypeTableViewCell: ReuseTableViewCell {
    @IBOutlet weak var thumbnailImageView: UIImageView!
    @IBOutlet weak var projectLabel: UILabel!
    @IBOutlet weak var postLabel: UILabel!
    @IBOutlet weak var writerLabel: UILabel!
    @IBOutlet weak var publishedAtLabel: UILabel!

    typealias Model = SponsoringPostModel

    override func prepareForReuse() {
        super.prepareForReuse()
        thumbnailImageView.sd_cancelCurrentImageLoad()
        thumbnailImageView.image = #imageLiteral(resourceName: "img-dummy-post-960-x-360")
    }

    func configure(with model: Model) {
        let (thumbnail, projectName, seriesName, postName, content, writerName, publishedAt) = (model.cover, model.project?.title, model.series?.name, model.title, model.previewText, model.project?.user?.username, model.publishedAt)

        thumbnailImageView.isHidden = thumbnail == nil

        if let thumbnail = thumbnail {
            let coverImageWithIC = "\(thumbnail)?w=720&h=720&quality=80&output=webp"
            if let url = URL(string: coverImageWithIC) {
                thumbnailImageView.sd_setImageWithFade(with: url, placeholderImage: #imageLiteral(resourceName: "img-dummy-post-960-x-360"), completed: nil)
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

