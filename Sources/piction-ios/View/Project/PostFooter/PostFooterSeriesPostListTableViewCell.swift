//
//  PostFooterSeriesPostListTableViewCell.swift
//  piction-ios
//
//  Created by jhseo on 01/10/2019.
//  Copyright © 2019 Piction Network. All rights reserved.
//

import UIKit
import PictionSDK

final class PostFooterSeriesPostListTableViewCell: ReuseTableViewCell {
    @IBOutlet weak var numberLabel: UILabel!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var currentImageContainerView: UIView!

    typealias Model = PostIndexModel

    override func layoutSubviews() {
        self.contentView.autoresizingMask = [.flexibleHeight]

        super.layoutSubviews()
    }

    func configure(with model: Model, current: Bool) {
        let (number, title) = (model.index, model.post?.title)

        if current {
            numberLabel.isHidden = true
            currentImageContainerView.isHidden = false
        } else {
            currentImageContainerView.isHidden = true
            numberLabel.isHidden = false
            numberLabel.text = "#\((number ?? 0) + 1)"
        }

        titleLabel.text = title
        titleLabel.font = current ? UIFont.boldSystemFont(ofSize: 14) : UIFont.systemFont(ofSize: 14)
    }
}
