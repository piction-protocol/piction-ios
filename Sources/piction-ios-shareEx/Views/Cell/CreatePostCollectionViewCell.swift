//
//  CreatePostCollectionViewCell.swift
//  piction-ios-shareEx
//
//  Created by jhseo on 2019/11/11.
//  Copyright © 2019 Piction Network. All rights reserved.
//

import UIKit

class CreatePostCollectionViewCell: ReuseCollectionViewCell {
    @IBOutlet weak var thumbnailImageView: UIImageView!
    @IBOutlet weak var coverImageLabel: UILabel!

    typealias Model = UIImage

    func configure(with model: Model, index: Int) {
        let (thumbnail) = model

        thumbnailImageView.image = thumbnail
        coverImageLabel.isHidden = index > 0
    }
}
