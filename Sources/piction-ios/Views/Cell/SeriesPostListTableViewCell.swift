//
//  SeriesPostListTableViewCell.swift
//  PictionView
//
//  Created by jhseo on 02/09/2019.
//  Copyright © 2019 Piction Network. All rights reserved.
//

import UIKit
import PictionSDK

final class SeriesPostListTableViewCell: ReuseTableViewCell {
    @IBOutlet weak var numberLabel: UILabel!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var subTitleLabel: UILabel!

    typealias Model = PostModel

    override func layoutSubviews() {
        self.contentView.autoresizingMask = [.flexibleHeight]

        super.layoutSubviews()
    }

    func configure(with model: Model, subscriptionInfo: SponsorshipModel?, number: Int) {
        let (title, date, membership) = (model.title, model.createdAt, model.membership)

        numberLabel.text = "#\(number)"

        titleLabel.text = title

        if membership == nil || (subscriptionInfo?.membership?.level ?? 0) >= (membership?.level ?? 0) {
            subTitleLabel.textColor = .pictionGray
            subTitleLabel.text = date?.toString(format: LocalizationKey.str_series_date_format.localized())
        } else {
            subTitleLabel.textColor = .pictionRed
            if membership != nil {
                subTitleLabel.text = (membership?.level ?? 0) == 0 ? LocalizationKey.str_series_subs_only.localized() :  LocalizationKey.str_series_membership_subs_only.localized(with: membership?.name ?? "")
            }
        }
    }
}
