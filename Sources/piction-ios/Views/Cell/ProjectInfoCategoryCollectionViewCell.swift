//
//  ProjectInfoCategoryCollectionViewCell.swift
//  piction-ios
//
//  Created by jhseo on 2020/02/21.
//  Copyright © 2020 Piction Network. All rights reserved.
//

import UIKit
import PictionSDK

class ProjectInfoCategoryCollectionViewCell: ReuseCollectionViewCell {
    @IBOutlet weak var categoryLabel: UILabel!

    typealias Model = CategoryModel

    func configure(with model: Model) {
        categoryLabel.text = model.name
    }
}
