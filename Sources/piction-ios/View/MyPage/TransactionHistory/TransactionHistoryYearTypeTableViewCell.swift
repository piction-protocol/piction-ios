//
//  TransactionHistoryYearTypeTableViewCell.swift
//  PictionView
//
//  Created by jhseo on 20/06/2019.
//  Copyright © 2019 Piction Network. All rights reserved.
//

import UIKit

final class TransactionHistoryYearTypeTableViewCell: ReuseTableViewCell {
    @IBOutlet weak var dateLabel: UILabel!

    typealias Model = String

    func configure(with model: Model) {

        dateLabel.text = "\(model)년"
    }
}
