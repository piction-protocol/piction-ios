//
//  ProjectInfoCategoryCollectionViewCell.swift
//  piction-ios
//
//  Created by jhseo on 2020/02/21.
//  Copyright © 2020 Piction Network. All rights reserved.
//

import UIKit
import PictionSDK

// MARK: - ReuseCollectionViewCell
class ProjectInfoCategoryCollectionViewCell: ReuseCollectionViewCell {
    @IBOutlet weak var categoryLabel: UILabel!

    typealias Model = CategoryModel
}

// MARK: - Public Method
extension ProjectInfoCategoryCollectionViewCell {
    func configure(with model: Model) {
        let (name) = (model.name)
        categoryLabel.text = name
    }
}
