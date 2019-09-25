//
//  TransactionHistoryListTypeTableViewCell.swift
//  PictionView
//
//  Created by jhseo on 20/06/2019.
//  Copyright © 2019 Piction Network. All rights reserved.
//

import UIKit
import PictionSDK

final class TransactionHistoryListTypeTableViewCell: ReuseTableViewCell {
    @IBOutlet weak var dateLabel: UILabel!
    @IBOutlet weak var amountLabel: UILabel!
    @IBOutlet weak var inOutLabel: UILabel!
    @IBOutlet weak var statusLabel: UILabel!

    typealias Model = TransactionModel

    func configure(with model: Model, dateTitle: Bool) {
        let (createdAt, amount, inOut) = (model.createdAt, model.amount, model.inOut)

        dateLabel.text = dateTitle ? createdAt?.toString(format: "MM.dd") : ""
        amountLabel.text = (inOut == "IN" ? "+" : "-") + amount.commaRepresentation + " PXL"
        inOutLabel.text = (inOut == "IN" ? "입금 " : "출금 ") + (createdAt?.toString(format: "h:mm") ?? "")
        statusLabel.text = "완료"
    }
}
