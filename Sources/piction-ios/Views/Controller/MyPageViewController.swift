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

// MARK: - UIViewController
final class MyPageViewController: UIViewController {
    var disposeBag = DisposeBag()

    @IBOutlet weak var tableView: UITableView! {
        didSet {
            // 로그인이 되어 있지 않으면 scroll되지 않도록 함
            tableView.isScrollEnabled = false
            // pull to refresh 추가
            tableView.refreshControl = refreshControl
        }
    }
    @IBOutlet weak var containerView: UIView!
    @IBOutlet weak var emptyView: UIView!
    private var refreshControl = UIRefreshControl()

    // 로그아웃 처리를 위한 Observable
    private let logout = PublishSubject<Void>()

    deinit {
        // 메모리 해제되는지 확인
        print("[deinit] \(String(describing: type(of: self)))")
    }
}

// MARK: - ViewModelBindable
extension MyPageViewController: ViewModelBindable {
    typealias ViewModel = MyPageViewModel

    func bindViewModel(viewModel: ViewModel) {
        let dataSource = configureDataSource()

        let input = MyPageViewModel.Input(
            viewWillAppear: rx.viewWillAppear.asDriver(), // 화면이 보여지기 전에
            viewWillLayoutSubviews: rx.viewWillLayoutSubviews.asDriver(), // subview의 layout이 갱신되기 전에
            selectedIndexPath: tableView.rx.itemSelected.asDriver(), // tableView의 row를 눌렀을 때
            logout: logout.asDriver(onErrorDriveWith: .empty()), // logout 버튼을 눌렀을 때
            refreshControlDidRefresh: refreshControl.rx.controlEvent(.valueChanged).asDriver() // pull to refresh 액션 시
        )

        let output = viewModel.build(input: input)

        // 화면이 보여지기 전에 NavigationBar 설정
        output
            .viewWillAppear
            .drive(onNext: { [weak self] in
                self?.navigationController?.configureNavigationBar(transparent: false, shadow: false)
            })
            .disposed(by: disposeBag)

        // subview의 layout이 갱신되기 전에
        output
           .viewWillLayoutSubviews
           .drive(onNext: { [weak self] in
               guard let `self` = self else { return }
               // pad 가로/세로 모드 전환 시 emptyView의 width 재 설정
               self.emptyView.frame.size.width = self.view.frame.size.width
           })
           .disposed(by: disposeBag)

        // 마이페이지 리스트를 tableViewdp 출력
        output
            .myPageList
            .do(onNext: { [weak self] _ in
                guard let `self` = self else { return }
                _ = self.emptyView.subviews.map { $0.removeFromSuperview() }
                self.emptyView.frame.size.height = 20
                self.containerView.frame.size.height = 104
                self.tableView.isScrollEnabled = true

                // 테이블 뷰의 스크롤 뷰 배경이 background의 색이기 때문에 footerView 추가해서 하단까지 스크롤 시 grouped tableView처럼 보이도록 함
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

        // UserInfoViewController를 header에 embed
        output
            .embedUserInfoViewController
            .drive(onNext: { [weak self] in
                self?.embedUserInfoViewController()
            })
            .disposed(by: disposeBag)

        // tableView의 row를 선택하면 각 설정화면으로 이동
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
                         // myProject 화면으로 push
                        self?.openView(type: .myProject, openType: .push)
                    case LocalizationKey.str_transactions.localized():
                         // transactionHistory 화면으로 push
                        self?.openView(type: .transactionHistory, openType: .push)
                    case LocalizationKey.str_deposit.localized():
                         // Deposit 화면으로 push
                        self?.openView(type: .deposit, openType: .push)
                    default:
                        break
                    }
                case .presentType(let title, _):
                    switch title {
                    case LocalizationKey.str_create_pin.localized():
                         // pincode 등록 화면을 출력
                        self?.openView(type: .registerPincode, openType: .present)
                    case LocalizationKey.str_change_pin.localized():
                        // check pincode 화면을 출력
                        self?.openView(type: .checkPincode(), openType: .present)
                    case LocalizationKey.str_change_basic_info.localized():
                        // 기본정보 변경 화면을 출력
                        self?.openView(type: .changeMyInfo, openType: .present)
                    case LocalizationKey.str_change_pw.localized():
                        // 비밀번호 변경 화면을 출력
                        self?.openView(type: .changePassword, openType: .present)
                    case LocalizationKey.str_terms.localized():
                        // 서비스 이용약관을 사파리로 출력
                        self?.openSafariViewController(url: "https://piction.network/terms")
                    case LocalizationKey.str_privacy.localized():
                        // 개인정보 처리방침을 사파리로 출력
                        self?.openSafariViewController(url: "https://piction.network/privacy")
                    case LocalizationKey.str_sign_out.localized():
                        // 로그아웃 처리
                        self?.logout.onNext(())
                    default:
                        break
                    }
                case .switchType: break
                }
            })
            .disposed(by: disposeBag)

        // emptyView 출력
        output
            .embedEmptyViewController
            .drive(onNext: { [weak self] style in
                guard let `self` = self else { return }
                Toast.loadingActivity(false) // 로딩 뷰 로딩 해제

                // header 제거
                _ = self.containerView.subviews.map { $0.removeFromSuperview() }
                self.containerView.frame.size.height = 0

                // 상단으로 스크롤
                self.tableView.setContentOffset(CGPoint(x: 0, y: -self.statusHeight-self.largeTitleNavigationHeight), animated: false)
                self.embedCustomEmptyViewController(style: style)
                self.tableView.isScrollEnabled = style != .defaultLogin
                self.tableView.reloadData()
            })
            .disposed(by: disposeBag)

        // 토스트 메시지 출력
        output
            .toastMessage
            .showToast()
            .disposed(by: disposeBag)

        // pull to refresh 로딩 및 해제
        output
            .isFetching
            .drive(refreshControl.rx.isRefreshing)
            .disposed(by: disposeBag)

        // 로딩 뷰
        output
            .activityIndicator
            .loadingActivity()
            .disposed(by: disposeBag)

        // 네트워크 오류 시 에러 팝업 출력
        output
            .showErrorPopup
            .drive(onNext: { [weak self] in
                Toast.loadingActivity(false) // 로딩 뷰 로딩 중이면 로딩 해제
                self?.showPopup(
                    title: LocalizationKey.popup_title_network_error.localized(),
                    message: LocalizationKey.msg_api_internal_server_error.localized(),
                    action: [LocalizationKey.retry.localized(), LocalizationKey.cancel.localized()]) { [weak self] in
                        // 다시 로딩
                        self?.viewModel?.loadRetryTrigger.onNext(())
                    }
            })
            .disposed(by: disposeBag)
    }
}

// MARK: - DataSource
extension MyPageViewController {
    private func configureDataSource() -> RxTableViewSectionedReloadDataSource<SectionType<MyPageSection>> {
        return RxTableViewSectionedReloadDataSource<SectionType<MyPageSection>>(
            // cell 설정
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

// MARK: - Private Method
extension MyPageViewController {
    // UserInfoViewController를 embed
    private func embedUserInfoViewController() {
        _ = containerView.subviews.map { $0.removeFromSuperview() }
        let vc = UserInfoViewController.make()
        embed(vc, to: containerView)
    }

    // emptyView를 embed
    private func embedCustomEmptyViewController(style: CustomEmptyViewStyle) {
        _ = emptyView.subviews.map { $0.removeFromSuperview() }
        emptyView.frame.size.height = visibleHeight
        let vc = CustomEmptyViewController.make(style: style)
        embed(vc, to: emptyView)
    }
}
