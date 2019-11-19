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
import SafariServices

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
    private var emptyHeight: CGFloat = 0
    private var refreshControl = UIRefreshControl()

    private let logout = PublishSubject<Void>()

    override func viewDidLoad() {
        super.viewDidLoad()

        emptyHeight = getVisibleHeight()
    }

    private func openMyProjectViewController() {
        let vc = MyProjectViewController.make()
        if let topViewController = UIApplication.topViewController() {
            topViewController.openViewController(vc, type: .push)
        }
    }

    private func openTransactionHistoryListViewController() {
        let vc = TransactionHistoryViewController.make()
        if let topViewController = UIApplication.topViewController() {
            topViewController.openViewController(vc, type: .push)
        }
    }

    private func openDepositViewController() {
        let vc = DepositViewController.make()
        if let topViewController = UIApplication.topViewController() {
            topViewController.openViewController(vc, type: .push)
        }
    }

    private func openChangeMyInfoViewController() {
        let vc = ChangeMyInfoViewController.make()
        if let topViewController = UIApplication.topViewController() {
            topViewController.openViewController(vc, type: .present)
        }
    }

    private func openChangePasswordViewController() {
        let vc = ChangePasswordViewController.make()
        if let topViewController = UIApplication.topViewController() {
            topViewController.openViewController(vc, type: .present)
        }
    }

    private func openCheckPincodeViewController() {
        let vc = CheckPincodeViewController.make(style: .change)
        if let topViewController = UIApplication.topViewController() {
            topViewController.openViewController(vc, type: .present)
        }
    }

    private func openRegisterPincodeViewController() {
        let vc = RegisterPincodeViewController.make()
        if let topViewController = UIApplication.topViewController() {
            topViewController.openViewController(vc, type: .present)
        }
    }

    private func openSafariViewController(url urlString: String) {
        guard let url = URL(string: urlString) else { return }
        let safariViewController = SFSafariViewController(url: url)
        self.present(safariViewController, animated: true, completion: nil)
    }

    private func embedUserInfoViewController() {
        _ = containerView.subviews.map { $0.removeFromSuperview() }
        let vc = UserInfoViewController.make()
        embed(vc, to: containerView)
    }

    private func embedCustomEmptyViewController(style: CustomEmptyViewStyle) {
        _ = emptyView.subviews.map { $0.removeFromSuperview() }
        emptyView.frame.size.height = emptyHeight
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
                FirebaseManager.screenName("마이페이지")
            })
            .disposed(by: disposeBag)

        output
            .myPageList
            .do(onNext: { [weak self] _ in
                _ = self?.emptyView.subviews.map { $0.removeFromSuperview() }
                self?.emptyView.frame.size.height = 0
                let view = UIView(frame: CGRect(x: 0, y: 0, width: SCREEN_W, height: SCREEN_H))
                if #available(iOS 13.0, *) {
                    view.backgroundColor = .groupTableViewBackground
                } else {
                    view.backgroundColor = UIColor(r: 242, g: 242, b: 247)
                }
                self?.emptyView.addSubview(view)
                self?.tableView.isScrollEnabled = true
            })
            .drive { $0 }
            .map { $0 }
            .bind(to: tableView.rx.items(dataSource: dataSource))
            .disposed(by: disposeBag)

        output
            .embedUserInfoViewController
            .drive(onNext: { [weak self] in
                self?.containerView.frame.size.height = 104
                self?.embedUserInfoViewController()
                self?.tableView.reloadData()
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
                    case LocalizedStrings.menu_my_project.localized():
                        self?.openMyProjectViewController()
                    case LocalizedStrings.str_transactions.localized():
                        self?.openTransactionHistoryListViewController()
                    case LocalizedStrings.str_deposit.localized():
                        self?.openDepositViewController()
                    default:
                        break
                    }
                case .presentType(let title, _):
                    switch title {
                    case LocalizedStrings.str_create_pin.localized():
                        self?.openRegisterPincodeViewController()
                    case LocalizedStrings.str_change_pin.localized():
                         self?.openCheckPincodeViewController()
                    case LocalizedStrings.str_change_basic_info.localized():
                        self?.openChangeMyInfoViewController()
                    case LocalizedStrings.str_change_pw.localized():
                        self?.openChangePasswordViewController()
                    case LocalizedStrings.str_terms.localized():
                        self?.openSafariViewController(url: "https://piction.network/terms")
                    case LocalizedStrings.str_privacy.localized():
                        self?.openSafariViewController(url: "https://piction.network/privacy")
                    case LocalizedStrings.str_sign_out.localized():
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
                self?.tableView.isScrollEnabled = style != .defaultLogin
                Toast.loadingActivity(false)
                _ = self?.containerView.subviews.map { $0.removeFromSuperview() }
                self?.containerView.frame.size.height = 0
                self?.embedCustomEmptyViewController(style: style)
                self?.tableView.contentOffset = CGPoint(x: 0, y: -LARGE_NAVIGATION_HEIGHT)
                self?.tableView.reloadData()
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
                    title: LocalizedStrings.popup_title_network_error.localized(),
                    message: LocalizedStrings.msg_api_internal_server_error.localized(),
                    action: LocalizedStrings.retry.localized()) { [weak self] in
                        self?.viewModel?.loadRetryTrigger.onNext(())
                    }
            })
            .disposed(by: disposeBag)
    }
}
