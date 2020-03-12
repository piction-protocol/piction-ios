//
//  TransactionDetailItemTypeTableViewCell.swift
//  PictionSDK
//
//  Created by jhseo on 29/08/2019.
//  Copyright © 2019 Piction Network. All rights reserved.
//

import UIKit

// MARK: - ReuseTableViewCell
final class TransactionDetailItemTypeTableViewCell: ReuseTableViewCell {
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var descriptionLabel: UILabel!

    typealias Model = (String, String, String)
}

// MARK: - Public Method
extension TransactionDetailItemTypeTableViewCell {
    func configure(with model: Model) {
        let (title, description, link) = model

        titleLabel.text = title

        // 링크가 있는 경우
        if let _ = URL(string: link) {
            let linkString = NSMutableAttributedString(string: description)
            // underline
            linkString.addAttribute(NSAttributedString.Key.underlineStyle, value: true, range: NSRange(location: 0, length: description.count))
            // 색상을 pictionBlue로 변경
            linkString.addAttribute(NSAttributedString.Key.foregroundColor, value: UIColor.pictionBlue, range: NSRange(location: 0, length: description.count))

            descriptionLabel.attributedText = linkString
        } else {
            descriptionLabel.text = description
        }
    }
}
