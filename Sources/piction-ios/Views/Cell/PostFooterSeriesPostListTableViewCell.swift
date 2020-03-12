//
//  PostFooterSeriesPostListTableViewCell.swift
//  piction-ios
//
//  Created by jhseo on 01/10/2019.
//  Copyright © 2019 Piction Network. All rights reserved.
//

import UIKit
import PictionSDK

// MARK: - ReuseTableViewCell
final class PostFooterSeriesPostListTableViewCell: ReuseTableViewCell {
    @IBOutlet weak var numberLabel: UILabel!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var currentImageContainerView: UIView!

    typealias Model = PostIndexModel

    // subview가 변경될 때
    override func layoutSubviews() {
        // height auto resizing
        self.contentView.autoresizingMask = [.flexibleHeight]

        super.layoutSubviews()
    }
}

// MARK: - Public Method
extension PostFooterSeriesPostListTableViewCell {
    func configure(with model: Model, current: Bool) {
        let (number, title) = (model.index, model.post?.title)

        // 현재 포스트와 같은 포스트면
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
