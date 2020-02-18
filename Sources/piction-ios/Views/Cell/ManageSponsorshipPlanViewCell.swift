//
//  ManageSponsorshipPlanTableViewCell.swift
//  piction-ios
//
//  Created by jhseo on 2019/11/22.
//  Copyright © 2019 Piction Network. All rights reserved.
//

import UIKit
import PictionSDK

class ManageSponsorshipPlanTableViewCell: ReuseTableViewCell {
    @IBOutlet weak var levelLabel: UILabel!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var postCountLabel: UILabel!
    @IBOutlet weak var priceLabel: UILabel!
    @IBOutlet weak var sponsorshipCountLabel: UILabel!
    @IBOutlet weak var sponsorshipLimitLabel: UILabel!

    typealias Model = PlanModel

    func configure(with model: Model) {
        let (level, title, postCount, sponsorshipCount, sponsorshipLimit, sponsorshipPrice) = (model.level, model.name, model.postCount, model.sponsorshipCount, model.sponsorshipLimit, model.sponsorshipPrice)

        levelLabel.text = (level ?? 0) == 0 ? LocalizationKey.str_sponsorship_plan_free_tier.localized() : LocalizationKey.str_sponsorship_plan_current_tier.localized(with: level ?? 0)
        titleLabel.text = title
        postCountLabel.text = "포스트 \(postCount ?? 0)개"
        priceLabel.text = level == 0 ? "무료" : "\(sponsorshipPrice.commaRepresentation) PXL"
        sponsorshipCountLabel.text = "구독자 \(sponsorshipCount ?? 0)"
        sponsorshipLimitLabel.text = " / \(sponsorshipLimit ?? 0)"
        sponsorshipLimitLabel.isHidden = sponsorshipLimit == nil
    }
}
