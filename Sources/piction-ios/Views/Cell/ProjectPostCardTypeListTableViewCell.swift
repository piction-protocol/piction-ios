//
//  ProjectPostCardTypeListTableViewCell.swift
//  PictionView
//
//  Created by jhseo on 03/07/2019.
//  Copyright © 2019 Piction Network. All rights reserved.
//

import UIKit
import PictionSDK

// MARK: - ReuseTableViewCell
final class ProjectPostCardTypeListTableViewCell: ReuseTableViewCell {
    @IBOutlet weak var thumbnailView: UIView!
    @IBOutlet weak var thumbnailImageView: UIImageView!
    @IBOutlet weak var seriesLabel: UILabel!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var dateLabel: UILabel!
    @IBOutlet weak var likeStackView: UIStackView!
    @IBOutlet weak var likeLabel: UILabel!
    @IBOutlet weak var lockView: UIView!
    @IBOutlet weak var maskImage: VisualEffectView!
    @IBOutlet weak var leftLockView: UIView!

    // cell이 재사용 될 때
    override func prepareForReuse() {
        super.prepareForReuse()
        thumbnailImageView.sd_cancelCurrentImageLoad() // 이미지 로딩 취소
        thumbnailImageView.image = #imageLiteral(resourceName: "img-dummy-post-960-x-360") // 이미지를 placeholder 이미지로 교체
    }

    // subview가 변경될 때
    override func layoutSubviews() {
        self.contentView.autoresizingMask = [.flexibleHeight]
        super.layoutSubviews()
    }
}

// MARK: - Public Method
extension ProjectPostCardTypeListTableViewCell {
    func configure(post: PostModel, subscriptionInfo: SponsorshipModel?, isWriter: Bool) {
        let (thumbnail, seriesName, title, publishedAt, likeCount, membership, status) = (post.cover, post.series?.name, post.title, post.publishedAt, post.likeCount, post.membership, post.status)

        // 썸네일 출력
        if let thumbnail = thumbnail {
            let coverImageWithIC = "\(thumbnail)?w=720&h=720&quality=80&output=webp"
            if let url = URL(string: coverImageWithIC) {
                thumbnailImageView.sd_setImageWithFade(with: url, placeholderImage: #imageLiteral(resourceName: "img-dummy-post-960-x-360"), completed: nil)
            }
        }

        seriesLabel.isHidden = seriesName == nil
        seriesLabel.text = seriesName

        titleLabel.text = title

        if let publishedAt = publishedAt {
            // 등록 날짜가 현재 날짜 이후면 예약 문구 출력
            if publishedAt.millisecondsSince1970 > Date().millisecondsSince1970 {
                dateLabel.text = publishedAt.toString(format: LocalizationKey.str_reservation_datetime_format.localized())
            } else {
                dateLabel.text = publishedAt.toString(format: LocalizationKey.str_date_format.localized())
            }
        }

        likeStackView.isHidden = (likeCount ?? 0) == 0
        likeLabel.text = "\(likeCount ?? 0)"

        // 비공개는 writer인 경우만 나오므로 writer인 경우 잠금 표시를 보여주지 않음
        if status == "PRIVATE" {
            thumbnailView.isHidden = thumbnail == nil
            maskImage.isHidden = true
            lockView.isHidden = true
            maskImage.blurRadius = 0
            lockView.backgroundColor = .clear
        } else {
            var needSubscription: Bool {
                // 크리에이터는 구독이 필요하지 않음
                if isWriter {
                    return false
                }
                // 멤버십이 없으면 구독이 필요하지 않음
                if membership == nil {
                    return false
                }
                // 멤버십이 있지만 구독중인 멤버십이 없는 경우 구독 필요
                if (membership?.level != nil) && (subscriptionInfo?.membership?.level == nil) {
                    return true
                }
                // 멤버십이 있고 구독중인 멤버십 레벨 보다 낮은 경우 구독이 필요하지 않음
                if (membership?.level ?? 0) <= (subscriptionInfo?.membership?.level ?? 0) {
                    return false
                }
                return true
            }

            if needSubscription { // 구독이 필요한 경우
                thumbnailView.isHidden = thumbnail == nil
                maskImage.isHidden = thumbnail == nil
                lockView.isHidden = thumbnail == nil
                leftLockView.isHidden = thumbnail != nil

                maskImage.blurRadius = thumbnail == nil ? 0 : 5
                lockView.backgroundColor = thumbnail == nil ? UIColor.pictionDarkGray.withAlphaComponent(0.2) : .clear
            } else { // 구독이 필요하지 않은 경우
                thumbnailView.isHidden = thumbnail == nil
                leftLockView.isHidden = true
                maskImage.isHidden = true
                lockView.isHidden = true
            }
        }
    }
}
