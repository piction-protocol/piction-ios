//
//  SearchSponsorTableViewCell.swift
//  PictionSDK
//
//  Created by jhseo on 19/08/2019.
//  Copyright © 2019 Piction Network. All rights reserved.
//

import UIKit
import PictionSDK

final class SearchSponsorTableViewCell: ReuseTableViewCell {
    @IBOutlet weak var thumbnailImageView: UIImageView!
    @IBOutlet weak var usernameLabel: UILabel!
    @IBOutlet weak var idLabel: UILabel!

    typealias Model = UserModel

    override func layoutSubviews() {
        self.contentView.autoresizingMask = [.flexibleHeight]

        super.layoutSubviews()
    }

    func configure(with model: Model) {
        let (thumbnail, username, loginId) = (model.picture, model.username, model.loginId)

        let userPictureWithIC = "\(thumbnail ?? "")?w=240&h=240&quality=80&output=webp"
        if let url = URL(string: userPictureWithIC) {
            thumbnailImageView.sd_setImageWithFade(with: url, placeholderImage: #imageLiteral(resourceName: "img-dummy-square-500-x-500"), completed: nil)
        } else {
            thumbnailImageView.image = #imageLiteral(resourceName: "img-dummy-square-500-x-500")
        }

        usernameLabel.text = username
        idLabel.text = "@\(loginId ?? "")"
    }
}
