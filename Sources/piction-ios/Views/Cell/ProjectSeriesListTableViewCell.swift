//
//  ProjectSeriesListTableViewCell.swift
//  PictionView
//
//  Created by jhseo on 03/07/2019.
//  Copyright © 2019 Piction Network. All rights reserved.
//

import UIKit
import PictionSDK

// MARK: - ReuseTableViewCell
final class ProjectSeriesListTableViewCell: ReuseTableViewCell {
    @IBOutlet weak var thumbnailImageView: UIImageView!
    @IBOutlet weak var backgroundThumbnailImageView: UIImageView!
    @IBOutlet weak var seriesLabel: UILabel!
    @IBOutlet weak var postCountLabel: UILabel!

    typealias Model = SeriesModel

    // cell이 재사용 될 때
    override func prepareForReuse() {
        super.prepareForReuse()
        thumbnailImageView.sd_cancelCurrentImageLoad() // 이미지 로딩 취소
        thumbnailImageView.image = #imageLiteral(resourceName: "img-dummy-post-960-x-360") // 이미지를 placeholder 이미지로 교체
        backgroundThumbnailImageView.sd_cancelCurrentImageLoad() // 이미지 로딩 취소
        backgroundThumbnailImageView.image = nil // 이미지 제거
    }
}

// MARK: - Public Method
extension ProjectSeriesListTableViewCell {
    func configure(with model: Model) {
        let (thumbnails, seriesName, postCount) = (model.thumbnails, model.name, model.postCount)

        // 썸네일 출력
        if let thumbnail = thumbnails?[safe: 0] {
            let coverImageWithIC = "\(thumbnail)?w=720&h=720&quality=80&output=webp"
            if let url = URL(string: coverImageWithIC) {
                thumbnailImageView.sd_setImageWithFade(with: url, placeholderImage: #imageLiteral(resourceName: "img-dummy-post-960-x-360"), completed: nil)
            }
        }

        // 썸네일 출력
        if let backgroundThumbnail = thumbnails?[safe: 1] {
            let coverImageWithIC = "\(backgroundThumbnail)?w=720&h=720&quality=80&output=webp"
            if let url = URL(string: coverImageWithIC) {
                backgroundThumbnailImageView.sd_setImageWithFade(with: url, placeholderImage: nil, completed: nil)
            }
        }

        seriesLabel.text = seriesName
        postCountLabel.text = LocalizationKey.str_series_posts_count.localized(with: postCount.commaRepresentation)
    }
}
