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

enum ManageMenu {
    case project
    case series
    case membership
}

final class ProjectViewController: UIViewController {
    var disposeBag = DisposeBag()

    private let menuHeight: CGFloat = 52
    private var contentOffset: CGPoint?

    @IBOutlet weak var infoBarButton: UIBarButtonItem!
    @IBOutlet weak var emptyView: UIView!

    private var stretchyHeader: ProjectHeaderView?

    private let changeMenu = BehaviorSubject<Int>(value: 0)
    private let subscription = PublishSubject<Void>()
    private let cancelSubscription = PublishSubject<Void>()
    private let membership = PublishSubject<Void>()
    private let deletePost = PublishSubject<Int>()
    private let deleteSeries = PublishSubject<Int>()
    private let updateSeries = PublishSubject<(String, SeriesModel)>()
    private let manageMenu = PublishSubject<ManageMenu>()
    private let subscriptionUser = PublishSubject<Void>()

    @IBOutlet weak var tableView: UITableView! {
        didSet {
            stretchyHeader = ProjectHeaderView.getView()
            stretchyHeader?.delegate = self
            if let stretchyHeader = stretchyHeader {
                stretchyHeader.stretchDelegate = self
                tableView.addSubview(stretchyHeader)
            }
        }
    }

    private func openDeletePostPopup(postId: Int) {
        let alertController = UIAlertController(title: nil, message: LocalizationKey.popup_title_delete_post.localized(), preferredStyle: .alert)
        let cancelButton = UIAlertAction(title: LocalizationKey.cancel.localized(), style: .cancel)
        let confirmButton = UIAlertAction(title: LocalizationKey.confirm.localized(), style: .default) { [weak self] _ in
            self?.deletePost.onNext(postId)
        }

        alertController.addAction(confirmButton)
        alertController.addAction(cancelButton)

        self.present(alertController, animated: true, completion: nil)
    }

    private func openDeleteSeriesPopup(seriesId: Int) {
        let alertController = UIAlertController(
        title: LocalizationKey.str_delete_series.localized(),
        message: nil,
        preferredStyle: UIAlertController.Style.alert)

        let deleteAction = UIAlertAction(
            title: LocalizationKey.delete.localized(),
            style: UIAlertAction.Style.destructive,
            handler: { [weak self] action in
                self?.deleteSeries.onNext(seriesId)
            })

        let cancelAction = UIAlertAction(
            title: LocalizationKey.cancel.localized(),
            style:UIAlertAction.Style.cancel,
            handler:{ action in
            })

        alertController.addAction(deleteAction)
        alertController.addAction(cancelAction)

        present(alertController, animated: true, completion: nil)
    }

    private func openUpdateSeriesPopup(series: SeriesModel) {
        let alertController = UIAlertController(
            title: LocalizationKey.str_modify_series.localized(),
            message: nil,
            preferredStyle: UIAlertController.Style.alert)

        alertController.addTextField(configurationHandler: { textField in
            textField.clearButtonMode = UITextField.ViewMode.always
            textField.text = series.name ?? ""
        })

        let insertAction = UIAlertAction(
            title: LocalizationKey.str_modify.localized(),
            style: UIAlertAction.Style.default,
            handler: { [weak self] action in
                guard let textFields = alertController.textFields else {
                    return
                }
                self?.updateSeries.onNext((textFields[0].text ?? "", series))
            })

        let cancelAction = UIAlertAction(
            title: LocalizationKey.cancel.localized(),
            style: UIAlertAction.Style.cancel,
            handler: { action in
            })

        alertController.addAction(insertAction)
        alertController.addAction(cancelAction)

        present(alertController, animated: true, completion: nil)
    }

    private func openCancelSubscriptionPopup() {
        let alertController = UIAlertController(title: nil, message: LocalizationKey.msg_want_to_unsubscribe.localized(), preferredStyle: .alert)
        let cancelButton = UIAlertAction(title: LocalizationKey.cancel.localized(), style: .cancel)
        let confirmButton = UIAlertAction(title: LocalizationKey.confirm.localized(), style: .default) { [weak self] _ in
            self?.cancelSubscription.onNext(())
        }

        alertController.addAction(confirmButton)
        alertController.addAction(cancelButton)

        self.present(alertController, animated: true, completion: nil)
    }

    private func embedCustomEmptyViewController(style: CustomEmptyViewStyle) {
        let vc = CustomEmptyViewController.make(style: style)
        if let footerView = self.tableView.tableFooterView {
            self.embed(vc, to: footerView)
        }
    }

    private func openSharePopup(url: String) {
        let activityViewController = UIActivityViewController(activityItems: [url], applicationActivities: [])

        activityViewController.excludedActivityTypes = [
            UIActivity.ActivityType.print,
            UIActivity.ActivityType.assignToContact,
            UIActivity.ActivityType.saveToCameraRoll,
            UIActivity.ActivityType.addToReadingList,
            UIActivity.ActivityType.postToFlickr,
            UIActivity.ActivityType.postToVimeo,
            UIActivity.ActivityType.openInIBooks
        ]

        if let topController = UIApplication.topViewController() {
            if UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiom.pad {
                activityViewController.modalPresentationStyle = .popover
                if let popover = activityViewController.popoverPresentationController {
                    popover.permittedArrowDirections = .up
                    popover.sourceView = topController.view
                    popover.sourceRect = CGRect(x: SCREEN_W, y: 64, width: 0, height: 0)
                }
            }
            topController.present(activityViewController, animated: true, completion: nil)
        }
    }

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        stretchyHeader?.frame.size.width = view.frame.size.width
    }

    private func configureDataSource() -> RxTableViewSectionedReloadDataSource<SectionType<ContentsSection>> {
        let dataSource = RxTableViewSectionedReloadDataSource<SectionType<ContentsSection>>(
            configureCell: { dataSource, tableView, indexPath, model in
                switch dataSource[indexPath] {
                case .postList(let post, let subscriptionInfo):
                    let cell: ProjectPostListTableViewCell = tableView.dequeueReusableCell(forIndexPath: indexPath)
                    cell.configure(with: post, subscriptionInfo: subscriptionInfo)
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
            return (self?.viewModel?.isWriter ?? false && FEATURE_EDITOR)
        })
        return dataSource
    }

    override var preferredContentSize: CGSize {
        get {
            guard let tableView = self.tableView else { return .zero }
            tableView.layoutIfNeeded()
            return tableView.contentSize
        }
        set {}
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        tableView.setInfiniteScrollStyle()
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
            membershipBtnDidTap:
                membership.asDriver(onErrorDriveWith: .empty()),
            changeMenu: changeMenu.asDriver(onErrorDriveWith: .empty()),
            infoBtnDidTap: infoBarButton.rx.tap.asDriver(),
            selectedIndexPath: tableView.rx.itemSelected.asDriver(),
            subscriptionUser: subscriptionUser.asDriver(onErrorDriveWith: .empty()),
            deletePost: deletePost.asDriver(onErrorDriveWith: .empty()),
            deleteSeries: deleteSeries.asDriver(onErrorDriveWith: .empty()),
            updateSeries: updateSeries.asDriver(onErrorDriveWith: .empty())
        )

        let output = viewModel.build(input: input)

        output
            .viewWillAppear
            .drive(onNext: { [weak self] in
                self?.navigationController?.configureNavigationBar(transparent: true, shadow: false)
                self?.navigationController?.navigationBar.barStyle = .black
                self?.navigationController?.navigationBar.tintColor = .white
                self?.tableView.setInfiniteScrollStyle()
            })
            .disposed(by: disposeBag)

        output
            .viewWillDisappear
            .drive(onNext: { [weak self] in
                self?.navigationController?.navigationBar.barStyle = .default
                self?.navigationController?.navigationBar.tintColor = UIView().tintColor
            })
            .disposed(by: disposeBag)

        output
            .selectedIndexPath
            .drive(onNext: { [weak self] indexPath in
                guard let uri = self?.viewModel?.uri else { return }
                switch dataSource[indexPath] {
                case .postList(let post, _):
                    self?.openPostViewController(uri: uri, postId: post.id ?? 0)
                case .seriesList(let series):
                    self?.openSeriesPostViewController(uri: uri, seriesId: series.id ?? 0)
                default:
                    break
                }
            })
            .disposed(by: disposeBag)

        output
            .contentList
            .do(onNext: { [weak self] _ in
                guard let `self` = self else { return }
                let footerHeight = SCREEN_H - self.statusHeight - self.navigationHeight - self.tabbarHeight - self.menuHeight
                self.tableView.tableFooterView = UIView(frame: CGRect(x: 0, y: 0, width: self.view.frame.size.width, height: footerHeight))
            })
            .drive { $0 }
            .map { [$0] }
            .bind(to: tableView.rx.items(dataSource: dataSource))
            .disposed(by: disposeBag)

        output
            .contentList
            .drive(onNext: { [weak self] list in
                guard let `self` = self else { return }
                let footerHeight = SCREEN_H - self.statusHeight - self.navigationHeight - self.tabbarHeight - self.menuHeight
                let height = self.preferredContentSize.height - (self.tableView.tableFooterView?.frame.size.height ?? 0)
                if height < footerHeight {
                    self.tableView.tableFooterView = UIView(frame: CGRect(x: 0, y: 0, width: self.view.frame.size.width, height: footerHeight - height))
                } else {
                    self.tableView.tableFooterView = UIView()
                }

                if let footerView = self.tableView.tableFooterView {
                    footerView.isHidden = list.items.count > 0
                }

                self.tableView.layoutIfNeeded()
                self.tableView.finishInfiniteScroll()

                if let contentOffset = self.contentOffset {
                    self.tableView.contentOffset = contentOffset
                }
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
            .drive(onNext: { [weak self] (isWriter, membershipList, subscriptionInfo, isActiveMembership) in
                self?.stretchyHeader?.configureSubscription(isWriter: isWriter, membershipList: membershipList, subscriptionInfo: subscriptionInfo, isActiveMembership: isActiveMembership)
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
            .drive(onNext: { [weak self] _ in
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
            .openSubscriptionUserViewController
            .drive(onNext: { [weak self] uri in
                if FEATURE_EDITOR {
                    self?.openSubscriptionUserViewController(uri: uri)
                }
            })
            .disposed(by: disposeBag)

        output
            .openMembershipListViewController
            .drive(onNext: { [weak self] uri in
                self?.openMembershipListViewController(uri: uri)
            })
            .disposed(by: disposeBag)

        output
            .activityIndicator
            .loadingActivity()
            .disposed(by: disposeBag)

        output
            .toastMessage
            .showToast()
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
//            print((1 - min(1, stretchFactor)) - 90 / 10)
            stretchyHeader?.maskImage.blurRadius = (1 - min(1, stretchFactor) - 0.9) * 50
        }
    }
}

extension ProjectViewController: ProjectHeaderViewDelegate {
    func postBtnDidTap() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.stretchyHeader?.controlMenuButton(menu: 0)
            self.changeMenu.onNext(0)
        }
        let menuTopPosition = self.statusHeight + self.navigationHeight + self.menuHeight
        if tableView.contentOffset.y >= -menuTopPosition {
            contentOffset = CGPoint(x: 0, y: -menuTopPosition)
        } else {
            contentOffset = tableView.contentOffset
        }
    }

    func seriesBtnDidTap() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.stretchyHeader?.controlMenuButton(menu: 1)
            self.changeMenu.onNext(1)
        }
        let menuTopPosition = self.statusHeight + self.navigationHeight + self.menuHeight
        if tableView.contentOffset.y >= -menuTopPosition {
            contentOffset = CGPoint(x: 0, y: -menuTopPosition)
        } else {
            contentOffset = tableView.contentOffset
        }
    }

    func subscriptionBtnDidTap() {
        self.subscription.onNext(())
    }

    func membershipBtnDidTap() {
        self.membership.onNext(())
    }

    func shareBtnDidTap() {
        guard let uri = self.viewModel?.uri else { return }
        guard let title = stretchyHeader?.titleLabel.text else { return }
        let stagingPath = AppInfo.isStaging ? "staging." : ""

        let url = "\(title) - Piction\nhttps://\(stagingPath)piction.network/project/\(uri)"

        self.openSharePopup(url: url)
    }

    func managementBtnDidTap() {
        guard let uri = self.viewModel?.uri else { return }
        let alertController = UIAlertController(
        title: nil,
        message: nil,
        preferredStyle: UIAlertController.Style.actionSheet)

        let manageProjectAction = UIAlertAction(
            title: "프로젝트 관리",
            style: UIAlertAction.Style.default,
            handler: { [weak self] action in
                self?.openCreateProjectViewController(uri: uri)
            })

        let manageSeriesAction = UIAlertAction(
            title: "시리즈 관리",
            style: UIAlertAction.Style.default,
            handler: { [weak self] action in
                self?.openManageSeriesViewController(uri: uri)
            })

        let manageMembershipAction = UIAlertAction(
            title: "Membership 관리",
            style: UIAlertAction.Style.default,
            handler: { [weak self] action in
                self?.openManageMembershipViewController(uri: uri)
            })

        let cancelAction = UIAlertAction(
            title: "취소",
            style:UIAlertAction.Style.cancel,
            handler:{ action in
            })

        alertController.addAction(manageProjectAction)
        alertController.addAction(manageSeriesAction)
        alertController.addAction(manageMembershipAction)
        alertController.addAction(cancelAction)

        present(alertController, animated: true, completion: nil)
    }

    func subscriptionUserBtnDidTap() {
        self.subscriptionUser.onNext(())
    }
}

extension ProjectViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        guard let section = self.viewModel?.sections[indexPath.row] else {
            return UISwipeActionsConfiguration()
        }
        guard let uri = self.viewModel?.uri else {
            return UISwipeActionsConfiguration()
        }

        let editAction = UIContextualAction(style: .normal, title: LocalizationKey.edit.localized(), handler: { [weak self] (action, view, completionHandler) in

            switch section {
            case .postList(let post, _):
                self?.openCreatePostViewController(uri: uri, postId: post.id ?? 0)
                completionHandler(true)
            case .seriesList(let series):
                self?.openUpdateSeriesPopup(series: series)
                completionHandler(true)
            default:
                completionHandler(false)
            }
        })

        let deleteAction = UIContextualAction(style: .destructive, title: LocalizationKey.delete.localized(), handler: { [weak self] (action, view, completionHandler) in

            switch section {
            case .postList(let post, _):
                self?.openDeletePostPopup(postId: post.id ?? 0)
                completionHandler(true)
            case .seriesList(let series):
                self?.openDeleteSeriesPopup(seriesId: series.id ?? 0)
                completionHandler(true)
            default:
                completionHandler(false)
            }
        })

        return UISwipeActionsConfiguration(actions: [deleteAction, editAction])
    }
}
