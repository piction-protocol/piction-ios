//
//  TransactionDetailItemTypeTableViewCell.swift
//  PictionSDK
//
//  Created by jhseo on 29/08/2019.
//  Copyright © 2019 Piction Network. All rights reserved.
//

import UIKit

final class TransactionDetailItemTypeTableViewCell: ReuseTableViewCell {
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var descriptionLabel: UILabel!

    typealias Model = (String, String, String)

    func configure(with model: Model) {
        let (title, description, link) = model

        titleLabel.text = title

        if let linkURL = URL(string: link) {
            let linkString = NSMutableAttributedString(string: description)
            linkString.addAttribute(NSAttributedString.Key.underlineStyle, value: true, range: NSRange(location: 0, length: description.count))
            linkString.addAttribute(NSAttributedString.Key.foregroundColor, value: UIColor(r: 26, g: 146, b: 255), range: NSRange(location: 0, length: description.count))

            descriptionLabel.attributedText = linkString
        } else {
            descriptionLabel.text = description
        }
    }
}
