//
//  TransactionDetailHeaderTypeTableViewCell.swift
//  PictionSDK
//
//  Created by jhseo on 29/08/2019.
//  Copyright © 2019 Piction Network. All rights reserved.
//

import UIKit
import PictionSDK

// MARK: - ReuseTableViewCell
final class TransactionDetailHeaderTypeTableViewCell: ReuseTableViewCell {
    @IBOutlet weak var titleLabel: UILabel!

    typealias Model = String
}

// MARK: - Public Method
extension TransactionDetailHeaderTypeTableViewCell {
    func configure(with title: Model) {
        titleLabel.text = title
    }
}
