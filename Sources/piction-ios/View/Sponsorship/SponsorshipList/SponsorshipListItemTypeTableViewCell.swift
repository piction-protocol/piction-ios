//
//  SponsorshipListItemTypeTableViewCell.swift
//  PictionSDK
//
//  Created by jhseo on 05/08/2019.
//  Copyright © 2019 Piction Network. All rights reserved.
//

import UIKit
import PictionSDK

final class SponsorshipListItemTypeTableViewCell: ReuseTableViewCell {
    @IBOutlet weak var amountLabel: UILabel!
    @IBOutlet weak var profileImageView: UIImageView!
    @IBOutlet weak var statusImageView: UIImageView!
    @IBOutlet weak var dateLabel: UILabel!
    @IBOutlet weak var messageLabel: UILabel!

    override func prepareForReuse() {
        super.prepareForReuse()
        profileImageView.image = #imageLiteral(resourceName: "img-dummy-userprofile-500-x-500")
    }

    typealias Model = SponsorshipModel

    func configure(with model: Model) {
        let (amount, creatorName, profileImage, status, createdAt) = (model.amount, model.creator?.username, model.creator?.picture, model.status, model.createdAt)

        if let profileImage = profileImage {
            let userPictureWithIC = "\(profileImage)?w=240&h=240&quality=80&output=webp"
            if let url = URL(string: userPictureWithIC) {
                profileImageView.sd_setImageWithFade(with: url, placeholderImage: #imageLiteral(resourceName: "img-dummy-userprofile-500-x-500"), completed: nil)
            }
        } else {
            profileImageView.image = #imageLiteral(resourceName: "img-dummy-userprofile-500-x-500")
        }

        statusImageView.image = nil

        amountLabel.text = "\(amount.commaRepresentation) PXL"
        messageLabel.text = LocalizedStrings.str_sponsorship_for.localized(with: creatorName ?? "")
        dateLabel.text = createdAt?.toString(format: "M/d\nhh:mm")
    }
}
