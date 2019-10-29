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
    @IBOutlet weak var subscriptionDateLabel: UILabel!

    typealias Model = SubscriptionUserModel

    func configure(with model: Model) {
        let (thumbnail, username, loginId, subscriptionDate) = (model.user?.picture, model.user?.username, model.user?.loginId, model.subscriptionDate)

        let userPictureWithIC = "\(thumbnail ?? "")?w=240&h=240&quality=80&output=webp"
        if let url = URL(string: userPictureWithIC) {
            profileImageView.sd_setImageWithFade(with: url, placeholderImage: #imageLiteral(resourceName: "img-dummy-square-500-x-500"), completed: nil)
        } else {
            profileImageView.image = #imageLiteral(resourceName: "img-dummy-square-500-x-500")
        }

        usernameLabel.text = username
        idLabel.text = "@\(loginId ?? "")"
        subscriptionDateLabel.text = subscriptionDate?.toString(format: "YYYY-MM-dd hh:mm")
    }
}
