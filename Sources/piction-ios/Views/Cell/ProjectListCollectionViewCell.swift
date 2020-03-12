//
//  ProjectListCollectionViewCell.swift
//  piction-ios
//
//  Created by jhseo on 16/10/2019.
//  Copyright © 2019 Piction Network. All rights reserved.
//

import UIKit
import PictionSDK

// MARK: - ReuseCollectionViewCell
final class ProjectListCollectionViewCell: ReuseCollectionViewCell {
    @IBOutlet weak var thumbnailImageView: UIImageView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var nicknameLabel: UILabel!
    @IBOutlet weak var updateLabel: UILabel!

    typealias Model = ProjectModel

    // cell이 재사용 될 때
    override func prepareForReuse() {
        super.prepareForReuse()
        thumbnailImageView.sd_cancelCurrentImageLoad() // 이미지 로딩 취소
        thumbnailImageView.image = #imageLiteral(resourceName: "img-dummy-square-500-x-500") // 이미지를 placeholder 이미지로 교체
    }
}

// MARK: - Public Method
extension ProjectListCollectionViewCell {
    func configure(with model: Model) {
        let (thumbnail, title, nickname, lastPublishedAt) = (model.thumbnail, model.title, model.user?.username, model.lastPublishedAt)

        // 썸네일 출력
        if let thumbnail = thumbnail {
            let thumbnailWithIC = "\(thumbnail)?w=720&h=720&quality=80&output=webp"
            if let url = URL(string: thumbnailWithIC) {
                thumbnailImageView.sd_setImageWithFade(with: url, placeholderImage: #imageLiteral(resourceName: "img-dummy-square-500-x-500"), completed: nil)
            }
        }

        titleLabel.text = title
        nicknameLabel.text = nickname

        if let lastPublishedAt = lastPublishedAt {
            // 현재 날짜와 일단위로 비교
            let diff = Calendar.current.dateComponents([.day], from: lastPublishedAt, to: Date())

            if let day = diff.day, day > 0 { // 현재 날짜의 일과 생성 날짜의 일이 하루 이상 차이나면
                updateLabel.isHidden = true
            } else {
                updateLabel.isHidden = false
            }
        } else {
            updateLabel.isHidden = true
        }
    }
}
