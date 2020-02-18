//
//  SponsorshipPlanListTableViewCell.swift
//  piction-ios
//
//  Created by jhseo on 2019/11/19.
//  Copyright © 2019 Piction Network. All rights reserved.
//

import UIKit
import PictionSDK

struct SponsorshipPlanListTableViewCellModel {
    let sponsorshipPlan: PlanModel
    let subscriptionInfo: SponsorshipModel?
    let postCount: Int
}

enum SponsorshipPlanButtonStyle {
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

class SponsorshipPlanListTableViewCell: ReuseTableViewCell {
    @IBOutlet weak var levelLabel: UILabel!
    @IBOutlet weak var subscriptionLimitLabel: UILabel!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var postCountLabel: UILabel!
    @IBOutlet weak var descriptionLabel: UILabel!
    @IBOutlet weak var statusLabel: UILabel!
    @IBOutlet weak var subscriptionLabel: UILabel!

    typealias Model = SponsorshipPlanListTableViewCellModel

    func configure(with model: Model) {
        let (sponsorshipPlan, subscriptionInfo, postCount) = (model.sponsorshipPlan, model.subscriptionInfo, model.postCount)

        var status: String {
            if let expireDate = subscriptionInfo?.expireDate,
                let sponsorshipPlanLevel = sponsorshipPlan.level,
                let subscriptionLevel = subscriptionInfo?.plan?.level,
                sponsorshipPlanLevel == subscriptionLevel {
                return expireDate.toString(format: LocalizationKey.str_sponsorship_plan_expire.localized())
            }
            if let sponsorshipPlanSponsorshipLimit = sponsorshipPlan.sponsorshipLimit,
                let sponsorshipPlanSponsorshipCount = sponsorshipPlan.sponsorshipCount,
                (sponsorshipPlanSponsorshipLimit > 0 && (sponsorshipPlanSponsorshipCount >= sponsorshipPlanSponsorshipLimit)) || sponsorshipPlan.sponsorshipLimit == 0 {
                return LocalizationKey.str_sponsorship_plan_not_avaliable.localized()
            }
            if let subscriptionLevel = subscriptionInfo?.plan?.level,
                let sponsorshipPlanLevel = sponsorshipPlan.level,
                subscriptionLevel > sponsorshipPlanLevel {
                return LocalizationKey.str_sponsorship_plan_not_avaliable.localized()
            }
            if let sponsorshipPlanSponsorshipLimit = sponsorshipPlan.sponsorshipLimit,
                let sponsorshipPlanSponsorshipCount = sponsorshipPlan.sponsorshipCount,
                sponsorshipPlanSponsorshipLimit > 0 {
                let remains = sponsorshipPlanSponsorshipLimit - sponsorshipPlanSponsorshipCount
                return LocalizationKey.str_sponsorship_plan_remain.localized(with: remains)
            }
            return ""
        }

        var buttonStyle: SponsorshipPlanButtonStyle {
            if let subscriptionLevel = subscriptionInfo?.plan?.level,
                let sponsorshipPlanLevel = sponsorshipPlan.level,
                subscriptionLevel == sponsorshipPlanLevel {
                return .subscribing
            }
            if let subscriptionLevel = subscriptionInfo?.plan?.level,
                let sponsorshipPlanLevel = sponsorshipPlan.level,
                subscriptionLevel > sponsorshipPlanLevel {
                return .dimmed
            }
            if let sponsorshipPlanSponsorshipLimit = sponsorshipPlan.sponsorshipLimit,
                let sponsorshipPlanSponsorshipCount = sponsorshipPlan.sponsorshipCount,
                (sponsorshipPlanSponsorshipLimit > 0 && (sponsorshipPlanSponsorshipCount >= sponsorshipPlanSponsorshipLimit)) || sponsorshipPlanSponsorshipLimit == 0 {
                return .dimmed
            }
            return .default
        }

        var subscriptionText: String {
            if let subscriptionLevel = subscriptionInfo?.plan?.level,
                let sponsorshipPlanLevel = sponsorshipPlan.level,
                subscriptionLevel == sponsorshipPlanLevel {
                return LocalizationKey.str_project_sponsorship_plan.localized()
            }
            if let price = sponsorshipPlan.sponsorshipPrice,
                price > 0 {
                return "\(price.commaRepresentation) \(LocalizationKey.str_sponsorship_plan_sponsorship_button.localized())"
            }
            return LocalizationKey.btn_subs_sponsorship_plan.localized()
        }

        levelLabel.text = (sponsorshipPlan.level ?? 0) == 0 ? LocalizationKey.str_sponsorship_plan_free_tier.localized() : LocalizationKey.str_sponsorship_plan_current_tier.localized(with: sponsorshipPlan.level ?? 0)
        subscriptionLimitLabel.isHidden = sponsorshipPlan.sponsorshipLimit == nil
        subscriptionLimitLabel.text = " · \(LocalizationKey.str_sponsorship_plan_limit.localized(with: sponsorshipPlan.sponsorshipLimit ?? 0))"
        titleLabel.text = sponsorshipPlan.name
        postCountLabel.text = LocalizationKey.str_sponsorship_plan_postcount.localized(with: postCount)
        descriptionLabel.text = sponsorshipPlan.description
        descriptionLabel.isHidden = (sponsorshipPlan.description ?? "") == ""
        statusLabel.text = status
        statusLabel.isHidden = status == ""
        subscriptionLabel.text = subscriptionText
        subscriptionLabel.backgroundColor = buttonStyle.backgroundColor
        subscriptionLabel.textColor = buttonStyle.textColor
        subscriptionLabel.layer.borderColor = buttonStyle.borderColor
        subscriptionLabel.layer.borderWidth = buttonStyle.borderWidth
    }
}
