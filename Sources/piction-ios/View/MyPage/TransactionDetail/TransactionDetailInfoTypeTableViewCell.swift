//
//  TransactionDetailInfoTypeTableViewCell.swift
//  PictionSDK
//
//  Created by jhseo on 29/08/2019.
//  Copyright © 2019 Piction Network. All rights reserved.
//

import UIKit
import PictionSDK

final class TransactionDetailInfoTypeTableViewCell: ReuseTableViewCell {
    @IBOutlet weak var amountLabel: UILabel!
    @IBOutlet weak var dateLabel: UILabel!
    @IBOutlet weak var timeLabel: UILabel!

    typealias Model = TransactionModel

    func configure(with model: Model) {
        let (createdAt , amount, inOut) = (model.createdAt, model.amount, model.inOut)

        amountLabel.text = (inOut == "IN" ? "+" : "-") + amount.commaRepresentation + " PXL"
        dateLabel.text = createdAt?.toString(format: "YYYY-MM-dd")
        timeLabel.text = createdAt?.toString(format: " · hh:mm:ss")

    }
}
