//
//  SearchTagTableViewCell.swift
//  piction-ios
//
//  Created by jhseo on 18/10/2019.
//  Copyright © 2019 Piction Network. All rights reserved.
//

import UIKit
import PictionSDK

final class SearchTagTableViewCell: ReuseTableViewCell {
    @IBOutlet weak var tagLabel: UILabel!
    @IBOutlet weak var projectCountLabel: UILabel!

    typealias Model = TagModel

    func configure(with model: Model) {
        let (tagName, projectCount) = (model.name, model.taggingCount)
        tagLabel.text = "#\(tagName ?? "")"
        projectCountLabel.text = LocalizationKey.str_project_count.localized(with: projectCount ?? 0)
    }
}
