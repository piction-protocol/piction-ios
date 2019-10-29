//
//  SeriesListTableViewCell.swift
//  piction-ios
//
//  Created by jhseo on 2019/10/25.
//  Copyright © 2019 Piction Network. All rights reserved.
//

import UIKit
import PictionSDK

class SeriesListTableViewCell: ReuseTableViewCell {
    @IBOutlet weak var titleLabel: UILabel!

    typealias Model = SeriesModel

    func configure(with model: Model) {
        let (title) = (model.name)

        titleLabel.text = title
    }
}
