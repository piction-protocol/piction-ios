//
//  SeriesPostViewController.swift
//  PictionSDK
//
//  Created by jhseo on 02/09/2019.
//  Copyright © 2019 Piction Network. All rights reserved.
//

import UIKit
import RxSwift
import RxCocoa
import ViewModelBindable
import RxDataSources
import PictionSDK

final class SeriesPostViewController: UIViewController {
    var disposeBag = DisposeBag()

    @IBOutlet weak var tableView: UITableView!

    @IBOutlet weak var coverView: UIView! {
        didSet {
            coverView.backgroundColor = UIColor(r: 51, g: 51, b: 51, a: 0.2)
        }
    }
    @IBOutlet weak var coverImageView: UIImageView!
    @IBOutlet weak var coverMaskImage: VisualEffectView!

    @IBOutlet weak var seriesTitleLabel: UILabel!
    @IBOutlet weak var postCountLabel: UILabel!
    @IBOutlet weak var sortButton: UIButton!
    @IBOutlet weak var emptyView: UIView!

    private func embedCustomEmptyViewController(style: CustomEmptyViewStyle) {
        _ = emptyView.subviews.map { $0.removeFromSuperview() }
        emptyView.frame.size.height = 350
        let vc = CustomEmptyViewController.make(style: style)
        embed(vc, to: emptyView)
    }

    private func configureDataSource() -> RxTableViewSectionedReloadDataSource<SectionType<ContentsSection>> {
        let dataSource = RxTableViewSectionedReloadDataSource<SectionType<ContentsSection>>(
            configureCell: { dataSource, tableView, indexPath, model in
                switch dataSource[indexPath] {
                case .seriesPostList(let post, let isSubscribing, let number):
                    let cell: SeriesPostListTableViewCell = tableView.dequeueReusableCell(forIndexPath: indexPath)
                    cell.configure(with: post, isSubscribing: isSubscribing, number: number)
                    return cell
                default:
                    let cell = UITableViewCell()
                    return cell
                }
        }, canEditRowAtIndexPath: { [weak self] (_, _) in
            return self?.viewModel?.isWriter ?? false
        })
        return dataSource
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        setInfiniteScrollStyle()
    }

    private func setInfiniteScrollStyle() {
        if #available(iOS 12.0, *) {
            if self.traitCollection.userInterfaceStyle == .dark {
                tableView.infiniteScrollIndicatorStyle = .white
            } else {
                tableView.infiniteScrollIndicatorStyle = .gray
            }
        }
    }
}

extension SeriesPostViewController: ViewModelBindable {
    typealias ViewModel = SeriesPostViewModel

    func bindViewModel(viewModel: ViewModel) {
        let dataSource = configureDataSource()

        tableView.addInfiniteScroll { [weak self] _ in
            self?.viewModel?.loadNextTrigger.onNext(())
        }
        tableView.setShouldShowInfiniteScrollHandler { [weak self] _ in
            return self?.viewModel?.shouldInfiniteScroll ?? false
        }

        let input = SeriesPostViewModel.Input(
            viewWillAppear: rx.viewWillAppear.asDriver(),
            viewWillDisappear: rx.viewWillDisappear.asDriver(),
            selectedIndexPath: tableView.rx.itemSelected.asDriver(),
            sortBtnDidTap: sortButton.rx.tap.asDriver()
        )

        let output = viewModel.build(input: input)

        output
            .viewWillAppear
            .drive(onNext: { [weak self] _ in
                self?.navigationController?.configureNavigationBar(transparent: false, shadow: true)
                self?.setInfiniteScrollStyle()
                let uri = self?.viewModel?.uri ?? ""
                let seriesId = self?.viewModel?.seriesId ?? 0
                FirebaseManager.screenName("시리즈상세_\(uri)_\(seriesId)")
            })
            .disposed(by: disposeBag)

        output
            .seriesInfo
            .drive(onNext: { [weak self] seriesInfo in
                self?.navigationItem.title = seriesInfo.name
                self?.seriesTitleLabel.text = seriesInfo.name
                self?.postCountLabel.text = LocalizedStrings.str_series_posts_count.localized(with: seriesInfo.postCount ?? 0)
            })
            .disposed(by: disposeBag)

        output
            .seriesThumbnail
            .drive(onNext: { [weak self] thumbnails in
                self?.coverMaskImage.blurRadius = 5
                if let coverImage = thumbnails[safe: 0] {
                    let coverImageWithIC = "\(coverImage)?w=656&h=246&quality=80&output=webp"
                    if let url = URL(string: coverImageWithIC) {
                        self?.coverImageView.sd_setImageWithFade(with: url, placeholderImage: UIImage())
                    }
                } else {
                    self?.coverImageView.image = nil
                }
            })
            .disposed(by: disposeBag)

        output
            .isDescending
            .drive(onNext: { [weak self] isDescending in
                self?.sortButton.setTitle(isDescending ? LocalizedStrings.str_sort_with_direction.localized(with: "↓") : LocalizedStrings.str_sort_with_direction.localized(with: "↑"), for: .normal)
            })
            .disposed(by: disposeBag)

        output
            .contentList
            .do(onNext: { [weak self] _ in
                _ = self?.emptyView.subviews.map { $0.removeFromSuperview() }
                self?.emptyView.frame.size.height = 0
            })
            .drive { $0 }
            .map { [$0] }
            .bind(to: tableView.rx.items(dataSource: dataSource))
            .disposed(by: disposeBag)

        output
            .contentList
            .drive(onNext: { [weak self] _ in
                self?.tableView.layoutIfNeeded()
                self?.tableView.finishInfiniteScroll()
            })
            .disposed(by: disposeBag)

        output
            .embedEmptyViewController
            .drive(onNext: { [weak self] style in
                guard let `self` = self else { return }
                self.embedCustomEmptyViewController(style: style)
            })
            .disposed(by: disposeBag)

        output
            .selectedIndexPath
            .drive(onNext: { [weak self] postInfo in
                let (uri, postId) = postInfo
                self?.openPostViewController(uri: uri, postId: postId)
            })
            .disposed(by: disposeBag)

        output
            .showErrorPopup
            .drive(onNext: { [weak self] in
                self?.tableView.finishInfiniteScroll()
                Toast.loadingActivity(false)
                self?.showPopup(
                    title: LocalizedStrings.popup_title_network_error.localized(),
                    message: LocalizedStrings.msg_api_internal_server_error.localized(),
                    action: LocalizedStrings.retry.localized()) { [weak self] in
                        self?.viewModel?.loadRetryTrigger.onNext(())
                    }
            })
            .disposed(by: disposeBag)

        output
            .activityIndicator
            .drive(onNext: { status in
                Toast.loadingActivity(status)
            })
            .disposed(by: disposeBag)
    }
}
