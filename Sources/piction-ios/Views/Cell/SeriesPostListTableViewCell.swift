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
        let (title, date, sponsorshipPlan) = (model.title, model.createdAt, model.plan)

        numberLabel.text = "#\(number)"

        titleLabel.text = title

        if sponsorshipPlan == nil || (subscriptionInfo?.plan?.level ?? 0) >= (sponsorshipPlan?.level ?? 0) {
            subTitleLabel.textColor = .pictionGray
            subTitleLabel.text = date?.toString(format: LocalizationKey.str_series_date_format.localized())
        } else {
            subTitleLabel.textColor = .pictionRed
            if sponsorshipPlan != nil {
                subTitleLabel.text = (sponsorshipPlan?.level ?? 0) == 0 ? LocalizationKey.str_series_subs_only.localized() :  LocalizationKey.str_series_sponsorship_plan_subs_only.localized(with: sponsorshipPlan?.name ?? "")
            }
        }
    }
}
