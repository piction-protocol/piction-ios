//
//  MyPagePresentTypeTableViewCell.swift
//  PictionSDK
//
//  Created by jhseo on 06/08/2019.
//  Copyright © 2019 Piction Network. All rights reserved.
//

import UIKit

// MARK: - MyPagePresentTypeTableViewCell
final class MyPagePresentTypeTableViewCell: ReuseTableViewCell {
    @IBOutlet weak var titleLabel: UILabel!

    typealias Model = String
}

// MARK: - Public Method
extension MyPagePresentTypeTableViewCell {
    func configure(with title: Model, align: NSTextAlignment) {
        titleLabel.text = title
        titleLabel.textAlignment = align
    }
}
