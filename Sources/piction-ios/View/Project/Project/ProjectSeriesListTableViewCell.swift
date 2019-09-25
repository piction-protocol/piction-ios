//
//  ProjectSeriesListTableViewCell.swift
//  PictionView
//
//  Created by jhseo on 03/07/2019.
//  Copyright © 2019 Piction Network. All rights reserved.
//

import UIKit
import PictionSDK

final class ProjectSeriesListTableViewCell: ReuseTableViewCell {
    @IBOutlet weak var thumbnailImageView: UIImageView!
    @IBOutlet weak var backgroundThumbnailImageView: UIImageView!
    @IBOutlet weak var seriesLabel: UILabel!
    @IBOutlet weak var postCountLabel: UILabel!

    typealias Model = SeriesModel

    func configure(with model: Model) {
        let (thumbnails, seriesName, postCount) = (model.thumbnails, model.name, model.postCount)

        if let thumbnail = thumbnails?[safe: 0] {
            let coverImageWithIC = "\(thumbnail)?w=656&h=246&quality=80&output=webp"
            if let url = URL(string: coverImageWithIC) {
                thumbnailImageView.sd_setImageWithFade(with: url, placeholderImage: #imageLiteral(resourceName: "img-dummy-projectcover-1440-x-450"), completed: nil)
            } else {
                thumbnailImageView.image = #imageLiteral(resourceName: "img-dummy-projectcover-1440-x-450")
            }
        }

        if let backgroundThumbnail = thumbnails?[safe: 1] {
            let coverImageWithIC = "\(backgroundThumbnail)?w=656&h=246&quality=80&output=webp"
            if let url = URL(string: coverImageWithIC) {
                backgroundThumbnailImageView.sd_setImageWithFade(with: url, placeholderImage: #imageLiteral(resourceName: "img-dummy-projectcover-1440-x-450"), completed: nil)
            } else {
                backgroundThumbnailImageView.image = #imageLiteral(resourceName: "img-dummy-projectcover-1440-x-450")
            }
        }
        seriesLabel.text = seriesName
        postCountLabel.text = "\(String(postCount ?? 0)) 포스트"
    }
}
