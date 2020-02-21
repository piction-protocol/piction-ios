//
//  ManageMembershipTableViewCell.swift
//  piction-ios
//
//  Created by jhseo on 2019/11/22.
//  Copyright © 2019 Piction Network. All rights reserved.
//

import UIKit
import PictionSDK

class ManageMembershipTableViewCell: ReuseTableViewCell {
    @IBOutlet weak var levelLabel: UILabel!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var postCountLabel: UILabel!
    @IBOutlet weak var priceLabel: UILabel!
    @IBOutlet weak var sponsorshipCountLabel: UILabel!
    @IBOutlet weak var sponsorshipLimitLabel: UILabel!

    typealias Model = MembershipModel

    func configure(with model: Model) {
        let (level, title, postCount, sponsorCount, sponsorLimit, price) = (model.level, model.name, model.postCount, model.sponsorCount, model.sponsorLimit, model.price)

        levelLabel.text = (level ?? 0) == 0 ? LocalizationKey.str_membership_free_tier.localized() : LocalizationKey.str_membership_current_tier.localized(with: level ?? 0)
        titleLabel.text = title
        postCountLabel.text = "포스트 \(postCount ?? 0)개"
        priceLabel.text = level == 0 ? "무료" : "\(price.commaRepresentation) PXL"
        sponsorshipCountLabel.text = "구독자 \(sponsorCount ?? 0)"
        sponsorshipLimitLabel.text = " / \(sponsorLimit ?? 0)"
        sponsorshipLimitLabel.isHidden = sponsorLimit == nil
    }
}
