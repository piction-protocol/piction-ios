//
//  TransactionDetailHeaderTypeTableViewCell.swift
//  PictionSDK
//
//  Created by jhseo on 29/08/2019.
//  Copyright © 2019 Piction Network. All rights reserved.
//

import UIKit
import PictionSDK

final class TransactionDetailHeaderTypeTableViewCell: ReuseTableViewCell {
    @IBOutlet weak var titleLabel: UILabel!

    typealias Model = String

    func configure(with model: Model) {

        titleLabel.text = model
    }
}
