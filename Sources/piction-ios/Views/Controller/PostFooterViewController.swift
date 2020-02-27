//
//  PostFooterViewController.swift
//  PictionView
//
//  Created by jhseo on 11/07/2019.
//  Copyright © 2019 Piction Network. All rights reserved.
//

import UIKit
import RxSwift
import RxCocoa
import ViewModelBindable
import RxDataSources
import PictionSDK

protocol PostFooterViewDelegate: class {
    func loadComplete()
    func reloadPost(postId: Int)
}

final class PostFooterViewController: UIViewController {
    var disposeBag = DisposeBag()

    @IBOutlet weak var dateLabel: UILabel!
    @IBOutlet weak var likeView: UIView! {
        didSet {
            likeView.layer.shadowOpacity = 1
            likeView.layer.shadowColor = UIColor(r: 0, g: 0, b: 0, a: 0.1).cgColor
            likeView.layer.shadowRadius = 4
            likeView.layer.shadowOffset = CGSize(width: 0, height: 1)
            likeView.layer.masksToBounds = false
            likeView.layer.borderColor = UIColor.white.cgColor
            likeView.layer.borderWidth = 0.5
            likeView.layer.cornerRadius = 40
        }
    }
    @IBOutlet weak var likeImageView: UIImageView!
    @IBOutlet weak var likeCountLabel: UILabel!
    @IBOutlet weak var likeButton: UIButton!

    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var seriesPostTitleStackView: UIStackView!
    @IBOutlet weak var seriesTitleLabel: UILabel!
    @IBOutlet weak var seriesPostCountLabel: UILabel!

    @IBOutlet weak var seriesAllPostButton: UIButton!
    @IBOutlet weak var footerView: UIView!

    weak var delegate: PostFooterViewDelegate?

    private func configureDataSource() -> RxTableViewSectionedReloadDataSource<SectionModel<String, PostIndexModel>> {
        return RxTableViewSectionedReloadDataSource<SectionModel<String, PostIndexModel>>(
            configureCell: { [weak self] dataSource, tableView, indexPath, model in
                let current = self?.viewModel?.postItem.id == model.post?.id
                let cell: PostFooterSeriesPostListTableViewCell = tableView.dequeueReusableCell(forIndexPath: indexPath)
                cell.configure(with: model, current: current)
                return cell
        })
    }
}

extension PostFooterViewController: ViewModelBindable {
    typealias ViewModel = PostFooterViewModel

    func bindViewModel(viewModel: ViewModel) {
        let dataSource = configureDataSource()

        let input = PostFooterViewModel.Input(
            viewWillAppear: rx.viewWillAppear.asDriver(),
            likeBtnDidTap: likeButton.rx.tap.asDriver().throttle(1, latest: true),
            selectedIndexPath: tableView.rx.itemSelected.asDriver(),
            seriesAllPostBtnDidTap: seriesAllPostButton.rx.tap.asDriver()
        )

        let output = viewModel.build(input: input)

        output
            .footerInfo
            .flatMap { [weak self] (postItem, seriesPostItems, isLike) -> Driver<[PostIndexModel]> in
                self?.controlLikeButton(isLike: isLike, likeCount: postItem.likeCount ?? 0)
                self?.dateLabel.text = postItem.publishedAt?.toString(format: LocalizationKey.str_post_date_format.localized())
                if seriesPostItems.count > 0 {
                    self?.seriesAllPostButton.isHidden = false
                    self?.seriesPostTitleStackView.isHidden = false
                    self?.setSeriesPostTitle(postItem: postItem, seriesItems: seriesPostItems)
                    self?.footerView.frame.size.height = 174
                } else {
                    self?.seriesAllPostButton.isHidden = true
                    self?.seriesPostTitleStackView.isHidden = true
                    self?.footerView.frame.size.height = 0
                }
                return Driver.just(seriesPostItems)
            }
            .drive { $0 }
            .map { [SectionModel(model: "", items: $0)] }
            .bind(to: tableView.rx.items(dataSource: dataSource))
            .disposed(by: disposeBag)

        output
            .footerInfo
            .drive(onNext: { [weak self] _ in
                self?.delegate?.loadComplete()
            })
            .disposed(by: disposeBag)

        output
            .addLike
            .drive(onNext: { [weak self] isExecuting in
                if isExecuting {
                    self?.controlLikeButton(isLike: true, likeCount: (Int(self?.likeCountLabel.text ?? "0") ?? 0) + 1)
                }
            })
            .disposed(by: disposeBag)

        output
            .selectSeriesPostItem
            .drive(onNext: { [weak self] indexPath in
                if let postId = dataSource[indexPath].post?.id {
                    self?.delegate?.reloadPost(postId: postId)
                }
            })
            .disposed(by: disposeBag)

        output
            .openSignInViewController
            .drive(onNext: { [weak self] uri in
                self?.openSignInViewController()
            })
            .disposed(by: disposeBag)

        output
            .openSeriesPostViewController
            .drive(onNext: { [weak self] (uri, seriesId) in
                self?.openSeriesPostViewController(uri: uri, seriesId: seriesId)
            })
            .disposed(by: disposeBag)
    }
}

extension PostFooterViewController {
    private func controlLikeButton(isLike: Bool, likeCount: Int) {
        self.likeCountLabel.textColor = isLike ? .pictionBlue : .pictionGray
        self.likeCountLabel.text = String(likeCount)
        self.likeButton.isEnabled = !isLike
        self.likeImageView.image = isLike ? #imageLiteral(resourceName: "icFavoriteOn") : #imageLiteral(resourceName: "icFavoriteOff")
    }

    private func setSeriesPostTitle(postItem: PostModel, seriesItems: [PostIndexModel]) {
        seriesTitleLabel.text = postItem.series?.name
        seriesPostCountLabel.text = LocalizationKey.str_series_posts_count.localized(with: postItem.series?.postCount.commaRepresentation ?? "0")
    }

    func changeBackgroundColor(color: UIColor) {
        guard let likeView = likeView else { return }
        likeView.backgroundColor = color
    }
}
