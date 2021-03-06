//
//  SearchProjectTableViewCell.swift
//  PictionView
//
//  Created by jhseo on 09/07/2019.
//  Copyright © 2019 Piction Network. All rights reserved.
//

import UIKit
import PictionSDK

// MARK: - ReuseTableViewCell
final class SearchProjectTableViewCell: ReuseTableViewCell {
    @IBOutlet weak var thumbnailImageView: UIImageView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var writerLabel: UILabel!

    typealias Model = ProjectModel

    // cell이 재사용 될 때
    override func prepareForReuse() {
        super.prepareForReuse()
        thumbnailImageView.sd_cancelCurrentImageLoad() // 이미지 로딩 취소
        thumbnailImageView.image = #imageLiteral(resourceName: "img-dummy-square-500-x-500") // 이미지를 placeholder 이미지로 교체
    }
}

// MARK: - Public Method
extension SearchProjectTableViewCell {
    func configure(with model: Model) {
        let (thumbnail, title, writer) = (model.thumbnail, model.title, model.user?.username)

        // 썸네일 출력
        if let thumbnail = thumbnail {
            let thumbnailWithIC = "\(thumbnail)?w=720&h=720&quality=80&output=webp"
            if let url = URL(string: thumbnailWithIC) {
                thumbnailImageView.sd_setImageWithFade(with: url, placeholderImage: #imageLiteral(resourceName: "img-dummy-square-500-x-500"), completed: nil)
            }
        }

        titleLabel.text = title
        writerLabel.text = writer
    }
}
