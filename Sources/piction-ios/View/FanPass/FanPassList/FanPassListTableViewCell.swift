//
//  FanPassListTableViewCell.swift
//  piction-ios
//
//  Created by jhseo on 2019/11/19.
//  Copyright © 2019 Piction Network. All rights reserved.
//

import UIKit
import PictionSDK

struct FanPassListTableViewCellModel {
    let fanPass: FanPassModel
    let subscriptionInfo: SubscriptionModel?
}

class FanPassListTableViewCell: ReuseTableViewCell {
    @IBOutlet weak var levelLabel: UILabel!
    @IBOutlet weak var subscriptionLimitLabel: UILabel!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var postCountLabel: UILabel!
    @IBOutlet weak var descriptionLabel: UILabel!
    @IBOutlet weak var statusLabel: UILabel!
    @IBOutlet weak var subscriptionLabel: UILabel!

    typealias Model = FanPassListTableViewCellModel

    func configure(with model: Model) {
        let (fanPass, subscriptionInfo) = (model.fanPass, model.subscriptionInfo)

        var status: String {
            if let expireDate = subscriptionInfo?.expireDate,
                let fanPassLevel = fanPass.level,
                let subscriptionLevel = subscriptionInfo?.fanPass?.level,
                fanPassLevel == subscriptionLevel {
                return expireDate.toString(format: LocalizedStrings.str_fanpasslist_subscription_expire.localized())
            }
            if let fanPassSubscriptionLimit = fanPass.subscriptionLimit,
                let fanPassSubscriptionCount = fanPass.subscriptionCount,
                (fanPassSubscriptionLimit > 0 && (fanPassSubscriptionCount >= fanPassSubscriptionLimit)) || fanPass.subscriptionLimit == 0 {
                return LocalizedStrings.str_fanpasslist_sold_out.localized()
            }
            if let subscriptionLevel = subscriptionInfo?.fanPass?.level,
                let fanPassLevel = fanPass.level,
                subscriptionLevel > fanPassLevel {
                return LocalizedStrings.str_fanpasslist_not_avaliable.localized()
            }
            if let fanPassSubscriptionLimit = fanPass.subscriptionLimit,
                let fanPassSubscriptionCount = fanPass.subscriptionCount,
                fanPassSubscriptionLimit > 0 {
                let remains = fanPassSubscriptionLimit - fanPassSubscriptionCount
                return LocalizedStrings.str_fanpasslist_subscription_remain.localized(with: remains)
            }
            return ""
        }

        var buttonDimmed: Bool {
            if let subscriptionLevel = subscriptionInfo?.fanPass?.level,
                let fanPassLevel = fanPass.level,
                subscriptionLevel >= fanPassLevel {
                return true
            }
            if let fanPassSubscriptionLimit = fanPass.subscriptionLimit,
                let fanPassSubscriptionCount = fanPass.subscriptionCount,
                (fanPassSubscriptionLimit > 0 && (fanPassSubscriptionCount >= fanPassSubscriptionLimit)) || fanPassSubscriptionLimit == 0 {
                return true
            }
            return false
        }

        var subscriptionText: String {
            if let subscriptionLevel = subscriptionInfo?.fanPass?.level,
                let fanPassLevel = fanPass.level,
                subscriptionLevel == fanPassLevel {
                return LocalizedStrings.str_project_subscribing.localized()
            }
            if let price = fanPass.subscriptionPrice,
                price > 0 {
                return "\(price.commaRepresentation) \(LocalizedStrings.str_fanpasslist_subscription_button.localized())"
            }
            return LocalizedStrings.btn_subs.localized()
        }

        levelLabel.text = (fanPass.level ?? 0) == 0 ? LocalizedStrings.str_fanpass_free_tier.localized() : LocalizedStrings.str_fanpass_current_tier.localized(with: fanPass.level ?? 0)
        subscriptionLimitLabel.isHidden = fanPass.subscriptionLimit == nil
        subscriptionLimitLabel.text = " · \(LocalizedStrings.str_fanpasslist_subscription_limit.localized(with: fanPass.subscriptionLimit ?? 0))"
        titleLabel.text = fanPass.name
        postCountLabel.text = LocalizedStrings.str_fanpasslist_postcount.localized(with: fanPass.postCount ?? 0)
        descriptionLabel.text = fanPass.description
        descriptionLabel.isHidden = (fanPass.description ?? "") == ""
        statusLabel.text = status
        statusLabel.isHidden = status == ""
        subscriptionLabel.text = subscriptionText
        subscriptionLabel.backgroundColor = buttonDimmed ? .pictionLightGray : UIColor(r: 51, g: 51, b: 51)
        subscriptionLabel.textColor = buttonDimmed ? .pictionGray : .white
    }
}
