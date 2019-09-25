//
//  MyPagePresentTypeTableViewCell.swift
//  PictionSDK
//
//  Created by jhseo on 06/08/2019.
//  Copyright © 2019 Piction Network. All rights reserved.
//

import UIKit

final class MyPagePresentTypeTableViewCell: ReuseTableViewCell {
    @IBOutlet weak var titleLabel: UILabel!

    typealias Model = String

    func configure(with model: Model, align: NSTextAlignment) {
        let (title) = (model)

        titleLabel.text = title
        titleLabel.textAlignment = align
    }
}
