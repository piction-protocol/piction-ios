//
//  SubscriptionSectionCollectionViewCell.swift
//  piction-ios
//
//  Created by jhseo on 17/10/2019.
//  Copyright © 2019 Piction Network. All rights reserved.
//

import UIKit
import RxSwift
import RxCocoa
import PictionSDK

final class SubscriptionSectionCollectionViewCell: ReuseCollectionViewCell {
    var disposeBag = DisposeBag()

    @IBOutlet weak var thumbnailImageView: UIImageView!
    @IBOutlet weak var updateLabel: UILabel!
    @IBOutlet weak var titleLabel: UILabel!

    @IBOutlet weak var postEmptyView: UILabel!
    @IBOutlet weak var postContainerView: UIView!
    @IBOutlet weak var postlastPublishedLabel: UILabel!
    @IBOutlet weak var postTitleLabel: UILabel!
    @IBOutlet weak var postThumbnailImageView: UIImageView!
    @IBOutlet weak var projectButton: UIButton!
    @IBOutlet weak var postButton: UIButton!

    typealias Model = SubscriptionSectionModel

    override func prepareForReuse() {
        super.prepareForReuse()
        disposeBag = DisposeBag()
    }

    private func openProjectViewController(uri: String) {
        let vc = ProjectViewController.make(uri: uri)
        if let topViewController = UIApplication.topViewController() {
            topViewController.openViewController(vc, type: .push)
        }
    }

    private func openPostViewController(uri: String, postId: Int) {
        let vc = PostViewController.make(uri: uri, postId: postId)
        if let topViewController = UIApplication.topViewController() {
            topViewController.openViewController(vc, type: .push)
        }
    }

    func configure(with model: Model) {
        let (thumbnail, title, postItem, lastPublishedAt) = (model.project.thumbnail, model.project.title, model.post, model.project.lastPublishedAt)

        projectButton.rx.tap.asDriver()
            .drive(onNext: { [weak self] in
                guard let uri = model.project.uri else { return }
                self?.openProjectViewController(uri: uri)
            })
            .disposed(by: disposeBag)

        postButton.rx.tap.asDriver()
            .drive(onNext: { [weak self] in
                guard let uri = model.project.uri else { return }
                guard let postId = model.post.id else { return }

                self?.openPostViewController(uri: uri, postId: postId)
            })
            .disposed(by: disposeBag)

        let thumbnailWithIC = "\(thumbnail ?? "")?w=720&h=720&quality=80&output=webp"
        if let url = URL(string: thumbnailWithIC) {
            thumbnailImageView.sd_setImageWithFade(with: url, placeholderImage: #imageLiteral(resourceName: "img-dummy-square-500-x-500"), completed: nil)
        } else {
            thumbnailImageView.image = #imageLiteral(resourceName: "img-dummy-square-500-x-500")
        }

        titleLabel.text = title

        if postItem.publishedAt == nil {
            self.updateLabel.isHidden = true
            self.postContainerView.isHidden = true
            self.postEmptyView.isHidden = false
        } else {
            self.postContainerView.isHidden = false
            self.postEmptyView.isHidden = true

            self.postTitleLabel.text = postItem.title

            if let lastPublishedAt = lastPublishedAt {
                let diff = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: lastPublishedAt, to: Date())

                if let day = diff.day, day > 0 {
                    self.updateLabel.isHidden = true
                } else {
                    self.updateLabel.isHidden = false
                }
            } else {
                self.updateLabel.isHidden = true
            }

            var lashPublishedDateTime: String {
                let diff = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: (postItem.publishedAt ?? Date()), to: Date())

                if let year = diff.year, year > 0 {
                    return LocalizedStrings.str_project_update_n_year.localized(with: year)
                } else if let month = diff.month, month > 0 {
                    return LocalizedStrings.str_project_update_n_month.localized(with: month)
                } else if let day = diff.day, day > 0 {
                    return LocalizedStrings.str_project_update_n_day.localized(with: day)
                } else if let hour = diff.hour, hour > 0 {
                    return LocalizedStrings.str_project_update_n_hour.localized(with: hour)
                } else if let minute = diff.minute, minute > 0 {
                    return LocalizedStrings.str_project_update_n_minute.localized(with: minute)
                } else {
                    return LocalizedStrings.str_project_update_n_now.localized()
                }
            }

            self.postlastPublishedLabel.text = lashPublishedDateTime

            if let cover = postItem.cover {
                let thumbnailWithIC = "\(cover)?w=720&h=720&quality=80&output=webp"
                if let url = URL(string: thumbnailWithIC) {
                    self.postThumbnailImageView.isHidden = false
                    self.postThumbnailImageView.sd_setImageWithFade(with: url, placeholderImage: #imageLiteral(resourceName: "img-dummy-square-500-x-500"), completed: nil)
                } else {
                    self.postThumbnailImageView.isHidden = true
                }
            } else {
                self.postThumbnailImageView.isHidden = true
            }
        }
    }
}
