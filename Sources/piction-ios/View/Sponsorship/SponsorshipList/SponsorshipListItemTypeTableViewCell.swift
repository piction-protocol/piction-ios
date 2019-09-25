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

    typealias Model = SponsorshipModel

    func configure(with model: Model) {
        let (amount, creatorName, profileImage, status, createdAt) = (model.amount, model.creator?.username, model.creator?.picture, model.status, model.createdAt)

        if let url = URL(string: profileImage ?? "") {
            profileImageView.sd_setImageWithFade(with: url, placeholderImage: #imageLiteral(resourceName: "img-dummy-userprofile-500-x-500"), completed: nil)
        } else {
            profileImageView.image = #imageLiteral(resourceName: "img-dummy-userprofile-500-x-500")
        }

        var message = ""

//        switch status {
//        case "SUCCESS":
//            statusImageView.image = nil
//            message = "후원하였습니다."
//        case "PENDING":
//            statusImageView.image = #imageLiteral(resourceName: "label_pending")
//            message = "송금하고 있습니다."
//        case "FAILED":
//            statusImageView.image = #imageLiteral(resourceName: "label_failed")
//            message = "송금이 실패했습니다."
//        default:
//            break
//        }

        statusImageView.image = nil
        message = "후원하였습니다."

        amountLabel.text = "\(amount.commaRepresentation) PXL"
        messageLabel.text = "\(creatorName ?? "")님에게 \(message)"
        dateLabel.text = createdAt?.toString(format: "hh:mm")
    }
}
