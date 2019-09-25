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

enum MyPageBySection {
    case Section(title: String, items: [MyPageItemType])
}

extension MyPageBySection: SectionModelType {
    typealias Item = MyPageItemType

    var items: [MyPageItemType] {
        switch self {
        case .Section(_, items: let items):
            return items.map { $0 }
        }
    }

    init(original: MyPageBySection, items: [Item]) {
        switch original {
        case .Section(title: let title, _):
            self = .Section(title: title, items: items)
        }
    }
}

enum MyPageItemType {
    case header(title: String)
    case pushType(title: String)
    case switchType(title: String, key: String)
    case presentType(title: String, align: NSTextAlignment)
    case underline
}


final class MyPageViewController: UIViewController {
    var disposeBag = DisposeBag()

    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var containerView: UIView!
    @IBOutlet weak var emptyView: UIView!
    private var emptyHeight: CGFloat = 0

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

    private func configureDataSource() -> RxTableViewSectionedReloadDataSource<MyPageBySection> {
        return RxTableViewSectionedReloadDataSource<MyPageBySection>(
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
            logout: logout.asDriver(onErrorDriveWith: .empty())
        )

        let output = viewModel.build(input: input)

        output
            .viewWillAppear
            .drive(onNext: { [weak self] in
                self?.navigationController?.setNavigationBarLine(false)
                self?.navigationController?.navigationBar.prefersLargeTitles = true
                self?.navigationController?.navigationBar.barStyle = .default
                self?.navigationController?.navigationBar.tintColor = UIView().tintColor
                self?.navigationController?.hideTransparentNavigationBar()
            })
            .disposed(by: disposeBag)

        output
            .viewWillDisappear
            .drive(onNext: { [weak self] in
                self?.navigationController?.setNavigationBarLine(true)
            })
            .disposed(by: disposeBag)

        output
            .myPageList
            .do(onNext: { [weak self] _ in
                _ = self?.emptyView.subviews.map { $0.removeFromSuperview() }
                self?.emptyView.frame.size.height = 0
                let view = UIView(frame: CGRect(x: 0, y: 0, width: SCREEN_W, height: SCREEN_H))
                view.backgroundColor = UIColor(r: 250, g: 250, b: 250)
                self?.emptyView.addSubview(view)
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
                    case "나의 프로젝트":
                        self?.openMyProjectViewController()
                    case "거래 내역":
                        self?.openTransactionHistoryListViewController()
                    case "픽션 지갑으로 입금":
                        self?.openDepositViewController()
                    default:
                        break
                    }
                case .presentType(let title, _):
                    switch title {
                    case "PIN 번호 등록":
                        self?.openRegisterPincodeViewController()
                    case "PIN 번호 변경":
                         self?.openCheckPincodeViewController()
                    case "기본정보 변경":
                        self?.openChangeMyInfoViewController()
                    case "비밀번호 변경":
                        self?.openChangePasswordViewController()
                    case "서비스 이용약관":
                        self?.openSafariViewController(url: "https://piction.network/terms")
                    case "개인정보 처리방침":
                        self?.openSafariViewController(url: "https://piction.network/privacy")
                    case "로그아웃":
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
    }
}
