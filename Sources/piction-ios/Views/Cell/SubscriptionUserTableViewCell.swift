//
//  SubscriptionUserTableViewCell.swift
//  piction-ios
//
//  Created by jhseo on 2019/10/28.
//  Copyright © 2019 Piction Network. All rights reserved.
//

import UIKit
import PictionSDK

// MARK: - ReuseTableViewCell
class SubscriptionUserTableViewCell: ReuseTableViewCell {
    @IBOutlet weak var profileImageView: UIImageView!
    @IBOutlet weak var usernameLabel: UILabel!
    @IBOutlet weak var idLabel: UILabel!
    @IBOutlet weak var levelLabel: UILabel!
    @IBOutlet weak var subscriptionDateLabel: UILabel!

    typealias Model = SponsorModel

    // cell이 재사용 될 때
    override func prepareForReuse() {
        super.prepareForReuse()
        profileImageView.sd_cancelCurrentImageLoad() // 이미지 로딩 취소
        profileImageView.image = #imageLiteral(resourceName: "img-dummy-square-500-x-500") // 이미지를 placeholder 이미지로 교체
    }
}

// MARK: - Public Method
extension SubscriptionUserTableViewCell {
    func configure(with model: Model) {
        let (profileImage, username, loginId, level, membershipName, subscriptionDate) = (model.sponsor?.picture, model.sponsor?.username, model.sponsor?.loginId, model.membership?.level, model.membership?.name, model.startedAt)

        // 썸네일 출력
        if let profileImage = profileImage {
            let userPictureWithIC = "\(profileImage)?w=240&h=240&quality=80&output=webp"
            if let url = URL(string: userPictureWithIC) {
                profileImageView.sd_setImageWithFade(with: url, placeholderImage: #imageLiteral(resourceName: "img-dummy-square-500-x-500"), completed: nil)
            }
        }

        usernameLabel.text = username
        idLabel.text = "@\(loginId ?? "")"

        // 레벨에 따라 문구 출력
        var levelText: String {
            if level == 0 {
                return LocalizationKey.str_membership_free_tier.localized()
            } else {
                return LocalizationKey.str_membership_current_tier.localized(with: level ?? 0)
            }
        }
        levelLabel.text = "\(levelText) - \(membershipName ?? "")"
        subscriptionDateLabel.text = subscriptionDate?.toString(format: "YYYY-MM-dd hh:mm")
    }
}
