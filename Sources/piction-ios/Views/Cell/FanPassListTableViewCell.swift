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
    let postCount: Int
}

enum FanPassButtonStyle {
    case dimmed
    case `default`
    case subscribing

    var backgroundColor: UIColor {
        switch self {
        case .dimmed:
            return .pictionLightGray
        case .default:
            return .pictionDarkGray
        case .subscribing:
            return .white
        }
    }

    var textColor: UIColor {
        switch self {
        case .dimmed:
            return .pictionGray
        case .default:
            return .white
        case .subscribing:
            return .pictionDarkGray
        }
    }

    var borderColor: CGColor {
        switch self {
        case .subscribing:
            return UIColor.pictionDarkGray.cgColor
        default:
            return UIColor.clear.cgColor
        }
    }

    var borderWidth: CGFloat {
        return self == .subscribing ? 2 : 0
    }
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
        let (fanPass, subscriptionInfo, postCount) = (model.fanPass, model.subscriptionInfo, model.postCount)

        var status: String {
            if let expireDate = subscriptionInfo?.expireDate,
                let fanPassLevel = fanPass.level,
                let subscriptionLevel = subscriptionInfo?.fanPass?.level,
                fanPassLevel == subscriptionLevel {
                return expireDate.toString(format: LocalizationKey.str_fanpasslist_subscription_expire.localized())
            }
            if let fanPassSubscriptionLimit = fanPass.subscriptionLimit,
                let fanPassSubscriptionCount = fanPass.subscriptionCount,
                (fanPassSubscriptionLimit > 0 && (fanPassSubscriptionCount >= fanPassSubscriptionLimit)) || fanPass.subscriptionLimit == 0 {
                return LocalizationKey.str_fanpasslist_sold_out.localized()
            }
            if let subscriptionLevel = subscriptionInfo?.fanPass?.level,
                let fanPassLevel = fanPass.level,
                subscriptionLevel > fanPassLevel {
                return LocalizationKey.str_fanpasslist_not_avaliable.localized()
            }
            if let fanPassSubscriptionLimit = fanPass.subscriptionLimit,
                let fanPassSubscriptionCount = fanPass.subscriptionCount,
                fanPassSubscriptionLimit > 0 {
                let remains = fanPassSubscriptionLimit - fanPassSubscriptionCount
                return LocalizationKey.str_fanpasslist_subscription_remain.localized(with: remains)
            }
            return ""
        }

        var buttonStyle: FanPassButtonStyle {
            if let subscriptionLevel = subscriptionInfo?.fanPass?.level,
                let fanPassLevel = fanPass.level,
                subscriptionLevel == fanPassLevel {
                return .subscribing
            }
            if let subscriptionLevel = subscriptionInfo?.fanPass?.level,
                let fanPassLevel = fanPass.level,
                subscriptionLevel > fanPassLevel {
                return .dimmed
            }
            if let fanPassSubscriptionLimit = fanPass.subscriptionLimit,
                let fanPassSubscriptionCount = fanPass.subscriptionCount,
                (fanPassSubscriptionLimit > 0 && (fanPassSubscriptionCount >= fanPassSubscriptionLimit)) || fanPassSubscriptionLimit == 0 {
                return .dimmed
            }
            return .default
        }

        var subscriptionText: String {
            if let subscriptionLevel = subscriptionInfo?.fanPass?.level,
                let fanPassLevel = fanPass.level,
                subscriptionLevel == fanPassLevel {
                return LocalizationKey.str_project_subscribing.localized()
            }
            if let price = fanPass.subscriptionPrice,
                price > 0 {
                return "\(price.commaRepresentation) \(LocalizationKey.str_fanpasslist_subscription_button.localized())"
            }
            return LocalizationKey.btn_subs.localized()
        }

        levelLabel.text = (fanPass.level ?? 0) == 0 ? LocalizationKey.str_fanpass_free_tier.localized() : LocalizationKey.str_fanpass_current_tier.localized(with: fanPass.level ?? 0)
        subscriptionLimitLabel.isHidden = fanPass.subscriptionLimit == nil
        subscriptionLimitLabel.text = " · \(LocalizationKey.str_fanpasslist_subscription_limit.localized(with: fanPass.subscriptionLimit ?? 0))"
        titleLabel.text = fanPass.name
        postCountLabel.text = LocalizationKey.str_fanpasslist_postcount.localized(with: postCount)
        descriptionLabel.text = fanPass.description
        descriptionLabel.isHidden = (fanPass.description ?? "") == ""
        statusLabel.text = status
        statusLabel.isHidden = status == ""
        subscriptionLabel.text = subscriptionText
        subscriptionLabel.backgroundColor = buttonStyle.backgroundColor
        subscriptionLabel.textColor = buttonStyle.textColor
        subscriptionLabel.layer.borderColor = buttonStyle.borderColor
        subscriptionLabel.layer.borderWidth = buttonStyle.borderWidth
    }
}
