//
//  HomeSubscribingPostsLargeTypeTableViewCell.swift
//  piction-ios
//
//  Created by Junghoon on 2020/02/27.
//  Copyright © 2020 Piction Network. All rights reserved.
//

import UIKit
import PictionSDK

// MARK: - ReuseTableViewCell
final class HomeSubscribingPostsLargeTypeTableViewCell: ReuseTableViewCell {
    @IBOutlet weak var thumbnailImageView: UIImageView!
    @IBOutlet weak var projectLabel: UILabel!
    @IBOutlet weak var postLabel: UILabel!
    @IBOutlet weak var writerLabel: UILabel!
    @IBOutlet weak var publishedAtLabel: UILabel!

    typealias Model = SponsoringPostModel

    // cell이 재사용 될 때
    override func prepareForReuse() {
        super.prepareForReuse()
        thumbnailImageView.sd_cancelCurrentImageLoad() // 이미지 로딩 취소
        thumbnailImageView.image = #imageLiteral(resourceName: "img-dummy-post-960-x-360") // 이미지를 placeholder 이미지로 교체
    }
}

// MARK: - Public Method
extension HomeSubscribingPostsLargeTypeTableViewCell {
    func configure(with model: Model) {
        let (thumbnail, projectName, seriesName, postName, content, writerName, publishedAt) = (model.cover, model.project?.title, model.series?.name, model.title, model.previewText, model.project?.user?.username, model.publishedAt)

        thumbnailImageView.isHidden = thumbnail == nil

        // 썸네일 출력
        if let thumbnail = thumbnail {
            let coverImageWithIC = "\(thumbnail)?w=720&h=720&quality=80&output=webp"
            if let url = URL(string: coverImageWithIC) {
                thumbnailImageView.sd_setImageWithFade(with: url, placeholderImage: #imageLiteral(resourceName: "img-dummy-post-960-x-360"), completed: nil)
            }
        }
        let series = seriesName != nil ? " ᐧ \(seriesName ?? "")" : ""
        projectLabel.text = "\(projectName ?? "")\(series)"
        postLabel.text = postName
        writerLabel.text = writerName

        var lashPublishedDateTime: String {
            // 현재 날짜와 년, 월, 일, 시간, 분단위로 비교
            let diff = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: (publishedAt ?? Date()), to: Date())

            if let year = diff.year, year > 0 { // 현재 날짜의 년도와 생성 날짜의 년도가 1년 이상 차이나면
                return LocalizationKey.str_post_update_n_year.localized(with: year)
            } else if let month = diff.month, month > 0 { // 현재 날짜의 월과 생성 날짜의 월이 1개월 이상 차이나면
                return LocalizationKey.str_post_update_n_month.localized(with: month)
            } else if let day = diff.day, day > 0 { // 현재 날짜의 일과 생성 날짜의 일이 하루 이상 차이나면
                return LocalizationKey.str_post_update_n_day.localized(with: day)
            } else if let hour = diff.hour, hour > 0 { // 현재 날짜의 시간과 생성 날짜의 시간이 1시간 이상 차이나면
                return LocalizationKey.str_post_update_n_hour.localized(with: hour)
            } else if let minute = diff.minute, minute > 0 { // 현재 날짜의 분과 생성 날짜의 분이 1분 이상 차이나면
                return LocalizationKey.str_post_update_n_minute.localized(with: minute)
            } else { // 현재 날짜의 분과 생성 날짜의 분이 1분 이하로 차이나면
                return LocalizationKey.str_post_update_n_now.localized()
            }
        }

        publishedAtLabel.text = lashPublishedDateTime
    }
}

