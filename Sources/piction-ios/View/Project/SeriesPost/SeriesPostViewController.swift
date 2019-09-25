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

    @IBOutlet weak var coverImageView: UIImageView!
    @IBOutlet weak var seriesTitleLabel: UILabel!
    @IBOutlet weak var postCountLabel: UILabel!
    @IBOutlet weak var sortButton: UIButton!
    @IBOutlet weak var emptyView: UIView!

    private func openPostViewController(uri: String, postId: Int) {
        let vc = PostViewController.make(uri: uri, postId: postId)
        if let topViewController = UIApplication.topViewController() {
            topViewController.openViewController(vc, type: .push)
        }
    }

    private func embedCustomEmptyViewController(style: CustomEmptyViewStyle) {
        _ = emptyView.subviews.map { $0.removeFromSuperview() }
        emptyView.frame.size.height = 350
        let vc = CustomEmptyViewController.make(style: style)
        embed(vc, to: emptyView)
    }

    private func configureDataSource() -> RxTableViewSectionedReloadDataSource<ContentsBySection> {
        let dataSource = RxTableViewSectionedReloadDataSource<ContentsBySection>(
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
}

extension SeriesPostViewController: ViewModelBindable {
    typealias ViewModel = SeriesPostViewModel

    func bindViewModel(viewModel: ViewModel) {
        let dataSource = configureDataSource()

        tableView.addInfiniteScroll { [weak self] _ in
            self?.viewModel?.loadTrigger.onNext(())
        }
        tableView.setShouldShowInfiniteScrollHandler { [weak self] _ in
            return self?.viewModel?.shouldInfiniteScroll ?? false
        }

        let input = SeriesPostViewModel.Input(
            viewWillAppear: rx.viewWillAppear.asDriver(),
            selectedIndexPath: tableView.rx.itemSelected.asDriver(),
            sortBtnDidTap: sortButton.rx.tap.asDriver()
        )

        let output = viewModel.build(input: input)

        output
            .viewWillAppear
            .drive(onNext: { [weak self] _ in
                self?.navigationController?.navigationBar.prefersLargeTitles = false
            })
            .disposed(by: disposeBag)

        output
            .seriesInfo
            .drive(onNext: { [weak self] seriesInfo in
                self?.seriesTitleLabel.text = seriesInfo.name
                self?.postCountLabel.text = "\(seriesInfo.postCount ?? 0) 포스트"
            })
            .disposed(by: disposeBag)

        output
            .coverImage
            .drive(onNext: { [weak self] coverImage in
                let coverImageWithIC = "\(coverImage)?w=656&h=246&quality=80&output=webp"
                if let url = URL(string: coverImageWithIC) {
                    self?.coverImageView.sd_setImageWithFade(with: url, placeholderImage: #imageLiteral(resourceName: "img-dummy-post-960-x-360"))
                } else {
                    self?.coverImageView.image = #imageLiteral(resourceName: "img-dummy-post-960-x-360")
                }
            })
            .disposed(by: disposeBag)

        output
            .isDescending
            .drive(onNext: { [weak self] isDescending in
                self?.sortButton.setTitle(isDescending ? "정렬 ↓" : "정렬 ↑", for: .normal)
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
    }
}
