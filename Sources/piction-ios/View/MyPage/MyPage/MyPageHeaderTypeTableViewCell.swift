//
//  MyPageHeaderTypeTableViewCell.swift
//  PictionSDK
//
//  Created by jhseo on 06/08/2019.
//  Copyright © 2019 Piction Network. All rights reserved.
//

import UIKit

final class MyPageHeaderTypeTableViewCell: ReuseTableViewCell {
    @IBOutlet weak var titleLabel: UILabel!

    typealias Model = String

    func configure(with model: Model) {
        let (title) = (model)

        titleLabel.text = title
    }
}
