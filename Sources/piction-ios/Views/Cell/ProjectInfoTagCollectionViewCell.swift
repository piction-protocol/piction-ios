//
//  ProjectInfoTagCollectionViewCell.swift
//  piction-ios
//
//  Created by jhseo on 2019/10/25.
//  Copyright © 2019 Piction Network. All rights reserved.
//

import UIKit

// MARK: - ReuseCollectionViewCell
class ProjectInfoTagCollectionViewCell: ReuseCollectionViewCell {
    @IBOutlet weak var tagLabel: UILabel!

    typealias Model = String
}

// MARK: - Public Method
extension ProjectInfoTagCollectionViewCell {
    func configure(with tag: Model) {
        tagLabel.text = "#\(tag)"
    }
}
