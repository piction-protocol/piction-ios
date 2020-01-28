//
//  MyPageViewController.swift
//  PictionView
//
//  Created by jhseo on 19/06/2019.
//  Copyright © 2019 Piction Network. All rights reserved.
//

import UIKit
import RxSwift
import RxCocoa
import ViewModelBindable
import RxDataSources

final class MyPageViewController: UIViewController {
    var disposeBag = DisposeBag()

    @IBOutlet weak var tableView: UITableView! {
        didSet {
            tableView.isScrollEnabled = false
            tableView.refreshControl = refreshControl
        }
    }
    @IBOutlet weak var containerView: UIView!
    @IBOutlet weak var emptyView: UIView!
    private var refreshControl = UIRefreshControl()

    private let logout = PublishSubject<Void>()

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        emptyView.frame.size.width = view.frame.size.width
    }

    private func embedUserInfoViewController() {
        _ = containerView.subviews.map { $0.removeFromSuperview() }
        let vc = UserInfoViewController.make()
        embed(vc, to: containerView)
    }

    private func embedCustomEmptyViewController(style: CustomEmptyViewStyle) {
        _ = emptyView.subviews.map { $0.removeFromSuperview() }
        emptyView.frame.size.height = visibleHeight
        let vc = CustomEmptyViewController.make(style: style)
        embed(vc, to: emptyView)
    }

    private func configureDataSource() -> RxTableViewSectionedReloadDataSource<SectionType<MyPageSection>> {
        return RxTableViewSectionedReloadDataSource<SectionType<MyPageSection>>(
            configureCell: { dataSource, tableView, indexPath, model in
                switch dataSource[indexPath] {
                case .header(let title):
                    let cell: MyPageHeaderTypeTableViewCell = tableView.dequeueReusableCell(forIndexPath: indexPath)
                    cell.configure(with: title)
                    return cell
                case .pushType(let title):
                    let cell: MyPagePushTypeTableViewCell = tableView.dequeueReusableCell(forIndexPath: indexPath)
                    cell.configure(with: title)
                    return cell
                case .presentType(let title, let align):
                    let cell: MyPagePresentTypeTableViewCell = tableView.dequeueReusableCell(forIndexPath: indexPath)
                    cell.configure(with: title, align: align)
                    return cell
                case .switchType(let title, let key):
                    let cell: MyPageSwitchTypeTableViewCell = tableView.dequeueReusableCell(forIndexPath: indexPath)
                    cell.configure(with: title, key: key)
                    return cell
                case .underline:
                    let cell: MyPageUnderlineTypeTableViewCell = tableView.dequeueReusableCell(forIndexPath: indexPath)
                    return cell
                }
        })
    }
}

extension MyPageViewController: ViewModelBindable {

    typealias ViewModel = MyPageViewModel

    func bindViewModel(viewModel: ViewModel) {
        let dataSource = configureDataSource()

        let input = MyPageViewModel.Input(
            viewWillAppear: rx.viewWillAppear.asDriver(),
            viewWillDisappear: rx.viewWillDisappear.asDriver(),
            selectedIndexPath: tableView.rx.itemSelected.asDriver(),
            logout: logout.asDriver(onErrorDriveWith: .empty()),
            refreshControlDidRefresh: refreshControl.rx.controlEvent(.valueChanged).asDriver()
        )

        let output = viewModel.build(input: input)

        output
            .viewWillAppear
            .drive(onNext: { [weak self] in
                self?.navigationController?.configureNavigationBar(transparent: false, shadow: false)
            })
            .disposed(by: disposeBag)

        output
            .myPageList
            .do(onNext: { [weak self] _ in
                guard let `self` = self else { return }
                _ = self.emptyView.subviews.map { $0.removeFromSuperview() }
                self.emptyView.frame.size.height = 20
                self.containerView.frame.size.height = 104
                self.tableView.isScrollEnabled = true
                let footerView = UIView(frame: CGRect(x: 0, y: 0, width: self.view.frame.size.height, height: self.view.frame.size.height))
                if #available(iOS 13, *) {
                    footerView.backgroundColor = .systemGroupedBackground
                } else {
                    footerView.backgroundColor = UIColor(r: 240, g: 240, b: 245)
                }
                self.emptyView.addSubview(footerView)
            })
            .drive { $0 }
            .map { $0 }
            .bind(to: tableView.rx.items(dataSource: dataSource))
            .disposed(by: disposeBag)

        output
            .embedUserInfoViewController
            .drive(onNext: { [weak self] in
                self?.embedUserInfoViewController()
            })
            .disposed(by: disposeBag)

        output
            .selectedIndexPath
            .drive(onNext: { [weak self] indexPath in
                switch dataSource[indexPath] {
                case .header,
                     .underline:
                    break
                case .pushType(let title):
                    switch title {
                    case LocalizationKey.menu_my_project.localized():
                        self?.openMyProjectViewController()
                    case LocalizationKey.str_transactions.localized():
                        self?.openTransactionHistoryListViewController()
                    case LocalizationKey.str_deposit.localized():
                        self?.openDepositViewController()
                    default:
                        break
                    }
                case .presentType(let title, _):
                    switch title {
                    case LocalizationKey.str_create_pin.localized():
                        self?.openRegisterPincodeViewController()
                    case LocalizationKey.str_change_pin.localized():
                         self?.openCheckPincodeViewController()
                    case LocalizationKey.str_change_basic_info.localized():
                        self?.openChangeMyInfoViewController()
                    case LocalizationKey.str_change_pw.localized():
                        self?.openChangePasswordViewController()
                    case LocalizationKey.str_terms.localized():
                        self?.openSafariViewController(url: "https://piction.network/terms")
                    case LocalizationKey.str_privacy.localized():
                        self?.openSafariViewController(url: "https://piction.network/privacy")
                    case LocalizationKey.str_sign_out.localized():
                        self?.logout.onNext(())
                    default:
                        break
                    }
                case .switchType: break
                }
            })
            .disposed(by: disposeBag)

        output
            .embedEmptyViewController
            .drive(onNext: { [weak self] style in
                guard let `self` = self else { return }
                Toast.loadingActivity(false)
                _ = self.containerView.subviews.map { $0.removeFromSuperview() }
                self.containerView.frame.size.height = 0
                self.tableView.setContentOffset(CGPoint(x: 0, y: -self.statusHeight-self.largeTitleNavigationHeight), animated: false)
                self.embedCustomEmptyViewController(style: style)
                self.tableView.isScrollEnabled = style != .defaultLogin
                self.tableView.reloadData()
            })
            .disposed(by: disposeBag)

        output
            .showToast
            .drive(onNext: { message in
                Toast.showToast(message)
            })
            .disposed(by: disposeBag)

        output
            .isFetching
            .drive(refreshControl.rx.isRefreshing)
            .disposed(by: disposeBag)

        output
            .activityIndicator
            .drive(onNext: { status in
                Toast.loadingActivity(status)
            })
            .disposed(by: disposeBag)

        output
            .showErrorPopup
            .drive(onNext: { [weak self] in
                Toast.loadingActivity(false)
                self?.showPopup(
                    title: LocalizationKey.popup_title_network_error.localized(),
                    message: LocalizationKey.msg_api_internal_server_error.localized(),
                    action: LocalizationKey.retry.localized()) { [weak self] in
                        self?.viewModel?.loadRetryTrigger.onNext(())
                    }
            })
            .disposed(by: disposeBag)
    }
}
