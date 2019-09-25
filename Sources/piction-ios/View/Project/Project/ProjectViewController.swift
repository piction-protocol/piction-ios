//
//  ProjectViewController.swift
//  PictionSDK
//
//  Created by jhseo on 24/06/2019.
//  Copyright © 2019 Piction Network. All rights reserved.
//

import UIKit
import RxSwift
import RxCocoa
import ViewModelBindable
import RxDataSources
import UIScrollView_InfiniteScroll
import GSKStretchyHeaderView
import PictionSDK

enum ContentsBySection {
    case Section(title: String, items: [ContentsItemType])
}

extension ContentsBySection: SectionModelType {
    typealias Item = ContentsItemType

    var items: [ContentsItemType] {
        switch self {
        case .Section(_, items: let items):
            return items.map { $0 }
        }
    }

    init(original: ContentsBySection, items: [Item]) {
        switch original {
        case .Section(title: let title, _):
            self = .Section(title: title, items: items)
        }
    }
}

enum ContentsItemType {
    case postList(post: PostModel, isSubscribing: Bool)
    case seriesPostList(post: PostModel, isSubscribing: Bool, number: Int)
    case seriesHeader(series: SeriesModel)
    case seriesList(series: SeriesModel)
}

final class ProjectViewController: UIViewController {
    var disposeBag = DisposeBag()

    @IBOutlet weak var infoBarButton: UIBarButtonItem!
    @IBOutlet weak var emptyView: UIView!

    private var stretchyHeader: ProjectHeaderView?

    private let changeMenu = BehaviorSubject<Int>(value: 0)
    private let subscription = PublishSubject<Void>()
    private let cancelSubscription = PublishSubject<Void>()

    @IBOutlet weak var tableView: UITableView! {
        didSet {
            tableView.estimatedRowHeight = 228
            tableView.rowHeight = UITableView.automaticDimension

            stretchyHeader = ProjectHeaderView.getView()
            stretchyHeader?.delegate = self
            if let stretchyHeader = stretchyHeader {
                stretchyHeader.stretchDelegate = self
                tableView.addSubview(stretchyHeader)
            }
        }
    }

    private func openPostViewController(uri: String, postId: Int) {
        let vc = PostViewController.make(uri: uri, postId: postId)
        if let topViewController = UIApplication.topViewController() {
            topViewController.openViewController(vc, type: .push)
        }
    }

    private func openSeriesPostViewController(uri: String, seriesId: Int) {
        let vc = SeriesPostViewController.make(uri: uri, seriesId: seriesId)
        if let topViewController = UIApplication.topViewController() {
            topViewController.openViewController(vc, type: .push)
        }
    }

    private func openProjectInfoViewController(uri: String) {
        let vc = ProjectInfoViewController.make(uri: uri)
        if let topViewController = UIApplication.topViewController() {
            topViewController.openViewController(vc, type: .push)
        }
    }

    private func openCreatePostViewController(uri: String, postId: Int = 0) {
        let vc = CreatePostViewController.make(uri: uri, postId: postId)
        if let topViewController = UIApplication.topViewController() {
            topViewController.openViewController(vc, type: .push)
        }
    }

    private func openSignInViewController() {
        let vc = SignInViewController.make()
        if let topViewController = UIApplication.topViewController() {
            topViewController.openViewController(vc, type: .present)
        }
    }

    private func openCancelSubscriptionPopup() {
        let alertController = UIAlertController(title: nil, message: "구독을 해제하시겠습니까?", preferredStyle: .alert)
        let cancelButton = UIAlertAction(title: "취소", style: .cancel)
        let confirmButton = UIAlertAction(title: "확인", style: .default) { [weak self] _ in
            self?.cancelSubscription.onNext(())
        }

        alertController.addAction(confirmButton)
        alertController.addAction(cancelButton)

        self.present(alertController, animated: true, completion: nil)
    }

    private func embedCustomEmptyViewController(style: CustomEmptyViewStyle) {
        _ = emptyView.subviews.map { $0.removeFromSuperview() }
        let vc = CustomEmptyViewController.make(style: style)
        embed(vc, to: emptyView)
    }

    private func configureDataSource() -> RxTableViewSectionedReloadDataSource<ContentsBySection> {
        let dataSource = RxTableViewSectionedReloadDataSource<ContentsBySection>(
            configureCell: { dataSource, tableView, indexPath, model in
                switch dataSource[indexPath] {
                case .postList(let post, let isSubscribing):
                    let cell: ProjectPostListTableViewCell = tableView.dequeueReusableCell(forIndexPath: indexPath)
                    cell.configure(with: post, isSubscribing: isSubscribing)
                    return cell
                case .seriesHeader(let series):
                    let cell: ProjectSeriesHeaderTableViewCell = tableView.dequeueReusableCell(forIndexPath: indexPath)
                    cell.configure(with: series)
                    return cell
                case .seriesList(let series):
                    let cell: ProjectSeriesListTableViewCell = tableView.dequeueReusableCell(forIndexPath: indexPath)
                    cell.configure(with: series)
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

    override var preferredContentSize: CGSize {
        get {
            self.tableView.layoutIfNeeded()
            return self.tableView.contentSize
        }
        set {}
    }
}

extension ProjectViewController: ViewModelBindable {
    typealias ViewModel = ProjectViewModel

    func bindViewModel(viewModel: ViewModel) {
        let dataSource = configureDataSource()

        tableView.rx.setDelegate(self)
            .disposed(by: disposeBag)

        tableView.addInfiniteScroll { [weak self] _ in
            self?.viewModel?.loadTrigger.onNext(())
        }
        tableView.setShouldShowInfiniteScrollHandler { [weak self] _ in
            return self?.viewModel?.shouldInfiniteScroll ?? false
        }

        let input = ProjectViewModel.Input(
            viewWillAppear: rx.viewWillAppear.asDriver(),
            viewWillDisappear: rx.viewWillDisappear.asDriver(),
            subscriptionBtnDidTap: subscription.asDriver(onErrorDriveWith: .empty()),
            cancelSubscriptionBtnDidTap: cancelSubscription.asDriver(onErrorDriveWith: .empty()),
            changeMenu: changeMenu.asDriver(onErrorDriveWith: .empty()),
            infoBtnDidTap: infoBarButton.rx.tap.asDriver(),
            selectedIndexPath: tableView.rx.itemSelected.asDriver(),
            contentOffset: tableView.rx.contentOffset.asDriver()
        )

        let output = viewModel.build(input: input)

        output
            .viewWillAppear
            .drive(onNext: { [weak self] in
                guard let `self` = self else { return }
                self.navigationController?.navigationBar.prefersLargeTitles = false
                self.navigationController?.navigationBar.barStyle = .black
                self.navigationController?.showTransparentNavigationBar()
                self.navigationController?.setNavigationBarLine(false)
                self.navigationController?.navigationBar.tintColor = .white
            })
            .disposed(by: disposeBag)

        output
            .viewWillDisappear
            .drive(onNext: { [weak self] in
                self?.navigationController?.navigationBar.barStyle = .default
                self?.navigationController?.hideTransparentNavigationBar()
                self?.navigationController?.setNavigationBarLine(true)
                self?.navigationController?.navigationBar.tintColor = UIView().tintColor
            })
            .disposed(by: disposeBag)

        output
            .openPostViewController
            .drive(onNext: { [weak self] postInfo in
                let (uri, postId) = postInfo
                self?.openPostViewController(uri: uri, postId: postId)
            })
            .disposed(by: disposeBag)

        output
            .openSeriesPostViewController
            .drive(onNext: { [weak self] seriesInfo in
                let (uri, seriesId) = seriesInfo
                self?.openSeriesPostViewController(uri: uri, seriesId: seriesId)
            })
            .disposed(by: disposeBag)

        output
            .contentList
            .do(onNext: { [weak self] _ in
                self?.emptyView.frame.size.height = SCREEN_H - DEFAULT_NAVIGATION_HEIGHT - TAB_HEIGHT - 52
            })
            .drive { $0 }
            .map { [$0] }
            .bind(to: tableView.rx.items(dataSource: dataSource))
            .disposed(by: disposeBag)

        output
            .contentList
            .drive(onNext: { [weak self] list in
                if list.items.count > 0 {
                    _ = self?.emptyView.subviews.map { $0.removeFromSuperview() }
                }
                let footerHeight = SCREEN_H - DEFAULT_NAVIGATION_HEIGHT - TAB_HEIGHT - 52
                let height = (self?.preferredContentSize.height ?? 0) - footerHeight
                if height < footerHeight {
                    self?.emptyView.frame.size.height = footerHeight - height
                } else {
                    self?.emptyView.frame.size.height = 0
                }
                self?.emptyView.isHidden = false
                self?.tableView.layoutIfNeeded()
                self?.tableView.finishInfiniteScroll()
                self?.tableView.reloadData()
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
            .projectInfo
            .drive(onNext: { [weak self] projectInfo in
                self?.stretchyHeader?.configureProjectInfo(model: projectInfo)
            })
            .disposed(by: disposeBag)

        output
            .subscriptionInfo
            .drive(onNext: { [weak self] (isWriter, isSubscribing) in
                self?.stretchyHeader?.configureSubscription(isWriter: isWriter, isSubscribing: isSubscribing)
            })
            .disposed(by: disposeBag)

        output
            .openCancelSubscriptionPopup
            .drive(onNext: { [weak self] _ in
                self?.openCancelSubscriptionPopup()
            })
            .disposed(by: disposeBag)

        output
            .openSignInViewController
            .drive(onNext: { [weak self] uri in
                self?.openSignInViewController()
            })
            .disposed(by: disposeBag)

        output
            .openCreatePostViewController
            .drive(onNext: { [weak self] uri in
                self?.openCreatePostViewController(uri: uri)
            })
            .disposed(by: disposeBag)

        output
            .openProjectInfoViewController
            .drive(onNext: { [weak self] uri in
                self?.openProjectInfoViewController(uri: uri)
            })
            .disposed(by: disposeBag)

        output
            .activityIndicator
            .drive(onNext: { [weak self] status in
                if status {
                    self?.view.makeToastActivity(.center)
                } else {
                    self?.view.hideToastActivity()
                }
            })
            .disposed(by: disposeBag)

        output
            .showToast
            .drive(onNext: { message in
                Toast.showToast(message)
            })
            .disposed(by: disposeBag)
    }
}

// MARK: - GSKStretchyHeaderViewStretchDelegate
extension ProjectViewController: GSKStretchyHeaderViewStretchDelegate {
    func stretchyHeaderView(_ headerView: GSKStretchyHeaderView, didChangeStretchFactor stretchFactor: CGFloat) {
        stretchyHeader?.maskImage.isHidden = false
        if stretchFactor > 0.1 {
            stretchyHeader?.maskImage.blurRadius = 0
        } else {
//            print(stretchFactor)
            print((1 - min(1, stretchFactor)) - 90 / 10)
            stretchyHeader?.maskImage.blurRadius = (1 - min(1, stretchFactor) - 0.9) * 50
        }
    }
}

extension ProjectViewController: ProjectHeaderViewProtocol {
    func postBtnDidTap() {
        self.changeMenu.onNext(0)
    }

    func seriesBtnDidTap() {
        self.changeMenu.onNext(1)
    }

    func subscriptionBtnDidTap() {
        self.subscription.onNext(())
    }
}

extension ProjectViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let editAction = UIContextualAction(style: .normal, title: "편집", handler: { [weak self] (action, view, completionHandler) in
            print("success")
            guard let section = self?.viewModel?.sections[indexPath.row] else { completionHandler(false)
                return
            }

            switch section {
            case .postList(let post, _):
                self?.openCreatePostViewController(uri: self?.viewModel?.uri ?? "", postId: post.id ?? 0)
                completionHandler(true)
            case .seriesList:
                completionHandler(false)
            default:
                completionHandler(false)
            }
        })
        return UISwipeActionsConfiguration(actions: [editAction])
    }
}
