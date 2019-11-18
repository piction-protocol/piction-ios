//
//  HomePopularTagsCollectionViewCell.swift
//  piction-ios
//
//  Created by jhseo on 17/10/2019.
//  Copyright © 2019 Piction Network. All rights reserved.
//

import UIKit
import RxSwift
import RxCocoa
import PictionSDK

final class HomePopularTagsCollectionViewCell: ReuseCollectionViewCell {
    var disposeBag = DisposeBag()

    @IBOutlet weak var thumbnailImageView: UIImageView!
    @IBOutlet weak var thumbnailVisualEffectView: VisualEffectView! {
        didSet {
            thumbnailVisualEffectView.blurRadius = 5
        }
    }
    @IBOutlet weak var tagLabel: UILabel!
    @IBOutlet weak var projectCountLabel: UILabel!
    @IBOutlet weak var eventLabel: UILabel!
    @IBOutlet weak var eventView: UIView!

    typealias Model = HomePopularTagsModel


    override func prepareForReuse() {
        super.prepareForReuse()
        disposeBag = DisposeBag()
    }

    func configure(with model: Model) {
        let (tagname, projectCount, label, thumbnail) = (model.tag.name, model.tag.taggingCount, model.tag.label, model.thumbnail)

        tagLabel.text = "#\(tagname ?? "")"
        projectCountLabel.text = LocalizedStrings.str_project_count.localized(with: projectCount ?? 0)
        eventLabel.text = label
        eventView.isHidden = label == nil

        if let thumbnail = thumbnail {
            let thumbnailWithIC = "\(thumbnail)?w=720&h=720&quality=80&output=webp"
            if let url = URL(string: thumbnailWithIC) {
                self.thumbnailImageView.sd_setImageWithFade(with: url, placeholderImage: #imageLiteral(resourceName: "img-dummy-square-500-x-500"), completed: nil)
            }
        } else {
            self.thumbnailImageView.image = #imageLiteral(resourceName: "img-dummy-square-500-x-500")
        }
    }
}
