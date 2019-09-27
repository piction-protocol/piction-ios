//
//  SponsorshipListButtonTypeTableViewCell.swift
//  PictionSDK
//
//  Created by jhseo on 05/08/2019.
//  Copyright © 2019 Piction Network. All rights reserved.
//

import UIKit
import PictionSDK

enum SponsorshipListButtonType {
    case sponsorship
    case history
}

final class SponsorshipListButtonTypeTableViewCell: ReuseTableViewCell {
    @IBOutlet weak var iconImageView: UIImageView!
    @IBOutlet weak var titleLabel: UILabel!

    func configure(type: SponsorshipListButtonType) {
        if type == .sponsorship {
            iconImageView.image = #imageLiteral(resourceName: "Support")
            titleLabel.text = LocalizedStrings.btn_user_sponsorship.localized()
        } else {
            iconImageView.image = #imageLiteral(resourceName: "Support_record")
            titleLabel.text = LocalizedStrings.btn_user_sponsorship_history.localized()
        }
    }
}
