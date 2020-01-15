//
//  ProjectInfoTagCollectionViewCell.swift
//  piction-ios
//
//  Created by jhseo on 2019/10/25.
//  Copyright © 2019 Piction Network. All rights reserved.
//

import UIKit

class ProjectInfoTagCollectionViewCell: ReuseCollectionViewCell {
    @IBOutlet weak var tagLabel: UILabel!

    typealias Model = String

    func configure(with model: Model) {
        tagLabel.text = "#\(model)"
    }
}
