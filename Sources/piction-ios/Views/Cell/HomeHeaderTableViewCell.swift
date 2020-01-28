//
//  HomeHeaderTableViewCell.swift
//  piction-ios
//
//  Created by jhseo on 2019/12/20.
//  Copyright © 2019 Piction Network. All rights reserved.
//

import UIKit
import PictionSDK

final class HomeHeaderTableViewCell: ReuseTableViewCell {
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var descriptionLabel: UILabel!

    typealias Model = HomeHeaderType

    func configure(with model: Model) {
        let type = model

        titleLabel.text = type == .notSubscribed ? LocalizationKey.str_subscribing_project_empty.localized() : LocalizationKey.str_post_empty.localized()
        descriptionLabel.text = type == .notSubscribed ? LocalizationKey.str_home_header_not_subscribing_subtitle.localized() : LocalizationKey.str_home_header_no_post_subtitle.localized()
    }
}
