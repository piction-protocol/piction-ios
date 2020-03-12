//
//  ManageSeriesTableViewCell.swift
//  piction-ios
//
//  Created by jhseo on 2019/10/25.
//  Copyright © 2019 Piction Network. All rights reserved.
//

import UIKit
import PictionSDK

// MARK: - ReuseTableViewCell
class ManageSeriesTableViewCell: ReuseTableViewCell {
    @IBOutlet weak var titleLabel: UILabel!

    typealias Model = SeriesModel
}

// MARK: - Public Method
extension ManageSeriesTableViewCell {
    func configure(with model: Model) {
        let (title) = (model.name)
        titleLabel.text = title
    }
}
