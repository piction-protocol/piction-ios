//
//  TransactionHistoryYearTypeTableViewCell.swift
//  PictionView
//
//  Created by jhseo on 20/06/2019.
//  Copyright © 2019 Piction Network. All rights reserved.
//

import UIKit

// MARK: - ReuseTableViewCell
final class TransactionHistoryYearTypeTableViewCell: ReuseTableViewCell {
    @IBOutlet weak var dateLabel: UILabel!

    typealias Model = String
}

// MARK: - Public Method
extension TransactionHistoryYearTypeTableViewCell {
    func configure(with date: Model) {
        dateLabel.text = LocalizationKey.str_year.localized(with: date)
    }
}
