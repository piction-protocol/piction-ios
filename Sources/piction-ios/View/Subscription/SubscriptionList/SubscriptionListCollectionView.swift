//
//  SubscriptionListCollectionView.swift
//  PictionSDK
//
//  Created by jhseo on 08/08/2019.
//  Copyright © 2019 Piction Network. All rights reserved.
//

import UIKit
import PictionSDK

final class SubscriptionListCollectionViewCell: ReuseCollectionViewCell {
    @IBOutlet weak var thumbnailImageView: UIImageView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var lastPublishedLabel: UILabel!

    typealias Model = ProjectModel

    func configure(with model: Model) {
        let (thumbnail, title, lastPublished) = (model.thumbnail, model.title, model.lastPublishedAt)

        let thumbnailWithIC = "\(thumbnail ?? "")?w=720&h=720&quality=80&output=webp"
        if let url = URL(string: thumbnailWithIC) {
            thumbnailImageView.sd_setImageWithFade(with: url, placeholderImage: #imageLiteral(resourceName: "img-dummy-square-500-x-500"), completed: nil)
        } else {
            thumbnailImageView.image = #imageLiteral(resourceName: "img-dummy-square-500-x-500")
        }

        titleLabel.text = title

        var lashPublishedDateTime: String {
            let diff = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: (lastPublished ?? Date()), to: Date())

            if let year = diff.year, year > 0 {
                return LocalizedStrings.str_project_update_n_year.localized(with: year)
            } else if let month = diff.month, month > 0 {
                return LocalizedStrings.str_project_update_n_month.localized(with: month)
            } else if let day = diff.day, day > 0 {
                return LocalizedStrings.str_project_update_n_day.localized(with: day)
            } else if let hour = diff.hour, hour > 0 {
                return LocalizedStrings.str_project_update_n_hour.localized(with: hour)
            } else if let minute = diff.minute, minute > 0 {
                return LocalizedStrings.str_project_update_n_minute.localized(with: minute)
            } else {
                return LocalizedStrings.str_project_update_n_now.localized()
            }
        }

        lastPublishedLabel.text = lastPublished == nil ? LocalizedStrings.str_project_no_post.localized() : lashPublishedDateTime
    }
}
