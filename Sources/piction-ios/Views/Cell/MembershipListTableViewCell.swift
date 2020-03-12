//
//  MembershipListTableViewCell.swift
//  piction-ios
//
//  Created by jhseo on 2019/11/19.
//  Copyright © 2019 Piction Network. All rights reserved.
//

import UIKit
import PictionSDK

// MARK: - MembershipListTableViewCellModel
struct MembershipListTableViewCellModel {
    let membership: MembershipModel
    let subscriptionInfo: SponsorshipModel?
    let postCount: Int
}

// MARK: - MembershipButtonStyle
enum MembershipButtonStyle {
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
            return UIColor(r: 209, g: 233, b: 255)
        }
    }

    var textColor: UIColor {
        switch self {
        case .dimmed:
            return .pictionGray
        case .default:
            return .white
        case .subscribing:
            return .pictionBlue
        }
    }
}

// MARK: - ReuseTableViewCell
final class MembershipListTableViewCell: ReuseTableViewCell {
    @IBOutlet weak var levelLabel: UILabel!
    @IBOutlet weak var subscriptionLimitLabel: UILabel!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var postCountLabel: UILabel!
    @IBOutlet weak var descriptionLabel: UILabel!
    @IBOutlet weak var statusLabel: UILabel!
    @IBOutlet weak var subscriptionLabel: UILabel!

    typealias Model = MembershipListTableViewCellModel
}

// MARK: - Public Method
extension MembershipListTableViewCell {
    func configure(with model: Model) {
        let (membership, subscriptionInfo, postCount) = (model.membership, model.subscriptionInfo, model.postCount)

        var status: String {
            if let expireDate = subscriptionInfo?.expireDate,
                let membershipLevel = membership.level,
                let subscriptionLevel = subscriptionInfo?.membership?.level,
                membershipLevel == subscriptionLevel { // 현재 멤버십 레벨과 현재 구독중인 멤버쉽 레벨이 같으면
                return expireDate.toString(format: LocalizationKey.str_membership_expire.localized())
            }
            if let membershipSponsorLimit = membership.sponsorLimit,
                let membershipSponsorCount = membership.sponsorCount,
                (membershipSponsorLimit > 0 && (membershipSponsorCount >= membershipSponsorLimit)) || membership.sponsorLimit == 0 { // 멤버십 구독자 수가 다 찼거나 같으면
                return LocalizationKey.str_membership_not_avaliable.localized()
            }
            if let subscriptionLevel = subscriptionInfo?.membership?.level,
                let membershipLevel = membership.level,
                subscriptionLevel > membershipLevel { // 구독중인 멤버십 레벨이 현재 멤버십 레벨보다 높으면
                return LocalizationKey.str_membership_not_avaliable.localized()
            }
            if let membershipSponsorLimit = membership.sponsorLimit,
                let membershipSponsorCount = membership.sponsorCount,
                membershipSponsorLimit > 0 { // 현재 멤버십 레벨이 0보다 크면(유료 구독이면)
                let remains = membershipSponsorLimit - membershipSponsorCount
                return LocalizationKey.str_membership_remain.localized(with: remains)
            }
            return ""
        }

        var statusTextColor: UIColor {
            if let _ = subscriptionInfo?.expireDate,
                let membershipLevel = subscriptionInfo?.membership?.level,
                let subscriptionLevel = subscriptionInfo?.membership?.level,
                membershipLevel == subscriptionLevel { // 현재 멤버십과 구독중인 멤버십의 레벨이 같으면
                return .pictionBlue
            } else {
                return UIColor(r: 153, g: 153, b: 153)
            }
        }

        var buttonStyle: MembershipButtonStyle {
            if let subscriptionLevel = subscriptionInfo?.membership?.level,
                let membershipLevel = membership.level,
                subscriptionLevel == membershipLevel { // 현재 멤버십과 구독중인 멤버십의 레벨이 같으면
                return .subscribing
            }
            if let subscriptionLevel = subscriptionInfo?.membership?.level,
                let membershipLevel = membership.level,
                subscriptionLevel > membershipLevel { // 현재 멤버십보다 구독중인 멤버십의 레벨이 높으면
                return .dimmed
            }
            if let membershipSponsorLimit = membership.sponsorLimit,
                let membershipSponsorCount = membership.sponsorCount,
                (membershipSponsorLimit > 0 && (membershipSponsorCount >= membershipSponsorLimit)) || membershipSponsorLimit == 0 { // 멤버십 구독자 수가 다 찼거나 같으면
                return .dimmed
            }
            return .default
        }

        var subscriptionText: String {
            if let subscriptionLevel = subscriptionInfo?.membership?.level,
                let membershipLevel = membership.level,
                subscriptionLevel == membershipLevel { // 현재 멤버십과 구독중인 멤버십의 레벨이 같으면
                return LocalizationKey.str_project_membership.localized()
            }
            if let price = membership.price,
                price > 0 { // 현재 멤버십 레벨이 0보다 크면(유료 구독이면)
                return "\(price.commaRepresentation) \(LocalizationKey.str_membership_sponsorship_button.localized())"
            }
            return LocalizationKey.btn_subs_membership.localized()
        }

        levelLabel.text = (membership.level ?? 0) == 0 ? LocalizationKey.str_membership_free_tier.localized() : LocalizationKey.str_membership_current_tier.localized(with: membership.level ?? 0)
        subscriptionLimitLabel.isHidden = membership.sponsorLimit == nil
        subscriptionLimitLabel.text = " · \(LocalizationKey.str_membership_limit.localized(with: membership.sponsorLimit ?? 0))"
        titleLabel.text = membership.name
        postCountLabel.text = LocalizationKey.str_membership_postcount.localized(with: postCount)
        descriptionLabel.text = membership.description
        descriptionLabel.isHidden = (membership.description ?? "") == ""
        statusLabel.text = status
        statusLabel.isHidden = status == ""
        statusLabel.textColor = statusTextColor
        subscriptionLabel.text = subscriptionText
        subscriptionLabel.backgroundColor = buttonStyle.backgroundColor
        subscriptionLabel.textColor = buttonStyle.textColor
    }
}
