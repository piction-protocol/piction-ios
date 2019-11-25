//
//  ManageFanPassTableViewCell.swift
//  piction-ios
//
//  Created by jhseo on 2019/11/22.
//  Copyright © 2019 Piction Network. All rights reserved.
//

import UIKit
import PictionSDK

class ManageFanPassTableViewCell: ReuseTableViewCell {
    @IBOutlet weak var levelLabel: UILabel!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var postCountLabel: UILabel!
    @IBOutlet weak var priceLabel: UILabel!
    @IBOutlet weak var subscriptionCountLabel: UILabel!
    @IBOutlet weak var subscriptionLimitLabel: UILabel!

    typealias Model = FanPassModel

    func configure(with model: Model) {
        let (level, title, postCount, subscriptionCount, subscriptionLimit, subscriptionPrice) = (model.level, model.name, model.postCount, model.subscriptionCount, model.subscriptionLimit, model.subscriptionPrice)

        levelLabel.text = (level ?? 0) == 0 ? LocalizedStrings.str_fanpass_free_tier.localized() : LocalizedStrings.str_fanpass_current_tier.localized(with: level ?? 0)
        titleLabel.text = title
        postCountLabel.text = "포스트 \(postCount ?? 0)개"
        priceLabel.text = level == 0 ? "무료" : "\(subscriptionPrice.commaRepresentation) PXL"
        subscriptionCountLabel.text = "구독자 \(subscriptionCount ?? 0)"
        subscriptionLimitLabel.text = " / \(subscriptionLimit ?? 0)"
        subscriptionLimitLabel.isHidden = subscriptionLimit == nil
    }
}
