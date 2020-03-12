//
//  MyPageHeaderTypeTableViewCell.swift
//  PictionSDK
//
//  Created by jhseo on 06/08/2019.
//  Copyright © 2019 Piction Network. All rights reserved.
//

import UIKit

// MARK: - ReuseTableViewCell
final class MyPageHeaderTypeTableViewCell: ReuseTableViewCell {
    @IBOutlet weak var titleLabel: UILabel!

    typealias Model = String
}

// MARK: - Public Method
extension MyPageHeaderTypeTableViewCell {
    func configure(with title: Model) {
        titleLabel.text = title
    }
}
