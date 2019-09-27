//
//  ProjectSeriesHeaderTableViewCell.swift
//  PictionView
//
//  Created by jhseo on 03/07/2019.
//  Copyright © 2019 Piction Network. All rights reserved.
//

import UIKit
import PictionSDK

final class ProjectSeriesHeaderTableViewCell: ReuseTableViewCell {
    @IBOutlet weak var seriesLabel: UILabel!
    @IBOutlet weak var postCountLabel: UILabel!

    typealias Model = SeriesModel

    func configure(with model: Model) {
        let (seriesName, postCount) = (model.name, model.postCount)

        seriesLabel.text = seriesName
        postCountLabel.text = LocalizedStrings.str_series_posts_count.localized(with: postCount ?? 0)
    }
}
