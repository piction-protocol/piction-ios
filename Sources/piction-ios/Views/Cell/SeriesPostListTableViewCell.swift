//
//  SeriesPostListTableViewCell.swift
//  PictionView
//
//  Created by jhseo on 02/09/2019.
//  Copyright © 2019 Piction Network. All rights reserved.
//

import UIKit
import PictionSDK

// MARK: - ReuseTableViewCell
final class SeriesPostListTableViewCell: ReuseTableViewCell {
    @IBOutlet weak var numberLabel: UILabel!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var subTitleLabel: UILabel!

    typealias Model = PostModel

    // subview가 변경될 때
    override func layoutSubviews() {
        self.contentView.autoresizingMask = [.flexibleHeight]

        super.layoutSubviews()
    }
}

// MARK: - Public Method
extension SeriesPostListTableViewCell {
    func configure(with model: Model, subscriptionInfo: SponsorshipModel?, number: Int) {
        let (title, date, membership) = (model.title, model.createdAt, model.membership)

        numberLabel.text = "#\(number)"

        titleLabel.text = title

        // 멤버십이 없거나 현재 멤버십의 레벨이 구독중인 멤버십 레벨보다 작으면
        if membership == nil || (subscriptionInfo?.membership?.level ?? 0) >= (membership?.level ?? 0) {
            subTitleLabel.textColor = .pictionGray
            subTitleLabel.text = date?.toString(format: LocalizationKey.str_series_date_format.localized())
        } else {
            subTitleLabel.textColor = .pictionRed
            if membership != nil {
                subTitleLabel.text = (membership?.level ?? 0) == 0 ? LocalizationKey.str_series_subs_only.localized() :  LocalizationKey.str_series_membership_subs_only.localized(with: membership?.name ?? "")
            }
        }
    }
}
