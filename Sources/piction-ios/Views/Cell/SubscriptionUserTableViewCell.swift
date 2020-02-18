//
//  SubscriptionUserTableViewCell.swift
//  piction-ios
//
//  Created by jhseo on 2019/10/28.
//  Copyright © 2019 Piction Network. All rights reserved.
//

import UIKit
import PictionSDK

class SubscriptionUserTableViewCell: ReuseTableViewCell {
    @IBOutlet weak var profileImageView: UIImageView!
    @IBOutlet weak var usernameLabel: UILabel!
    @IBOutlet weak var idLabel: UILabel!
    @IBOutlet weak var levelLabel: UILabel!
    @IBOutlet weak var subscriptionDateLabel: UILabel!

    override func prepareForReuse() {
        super.prepareForReuse()
        profileImageView.sd_cancelCurrentImageLoad()
        profileImageView.image = #imageLiteral(resourceName: "img-dummy-square-500-x-500")
    }

    typealias Model = SubscriberModel

    func configure(with model: Model) {
        let (profileImage, username, loginId, level, fanPassName, subscriptionDate) = (model.subscriber?.picture, model.subscriber?.username, model.subscriber?.loginId, model.fanPass?.level, model.fanPass?.name, model.startedAt)

        if let profileImage = profileImage {
            let userPictureWithIC = "\(profileImage)?w=240&h=240&quality=80&output=webp"
            if let url = URL(string: userPictureWithIC) {
                profileImageView.sd_setImageWithFade(with: url, placeholderImage: #imageLiteral(resourceName: "img-dummy-square-500-x-500"), completed: nil)
            }
        }

        usernameLabel.text = username
        idLabel.text = "@\(loginId ?? "")"
        var levelText: String {
            if level == 0 {
                return LocalizationKey.str_sponsorship_plan_free_tier.localized()
            } else {
                return LocalizationKey.str_sponsorship_plan_current_tier.localized(with: level ?? 0)
            }
        }
        levelLabel.text = "\(levelText) - \(fanPassName ?? "")"
        subscriptionDateLabel.text = subscriptionDate?.toString(format: "YYYY-MM-dd hh:mm")
    }
}
