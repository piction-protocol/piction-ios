//
//  MembershipListViewController.swift
//  piction-ios
//
//  Created by jhseo on 2019/11/19.
//  Copyright © 2019 Piction Network. All rights reserved.
//

import UIKit
import RxSwift
import RxCocoa
import ViewModelBindable
import RxDataSources
import PictionSDK

// MARK: - UIViewController
final class MembershipListViewController: UIViewController {
    var disposeBag = DisposeBag()

    @IBOutlet weak var emptyView: UIView!

    @IBOutlet weak var thumbnailImageView: UIImageView!
    @IBOutlet weak var writerLabel: UILabel!
    @IBOutlet weak var currentSubscriptionMembershipTitleLabel: UILabel!
    @IBOutlet weak var currentSubscriptionMembershipView: UIView!
    @IBOutlet weak var showAllMembershipButton: UIButton!
    @IBOutlet weak var currentPostMembershipInfo: UIView!
    @IBOutlet weak var currentPostTitleLabel: UILabel!
    @IBOutlet weak var closeButton: UIBarButtonItem!
    @IBOutlet weak var tableView: UITableView!

    override func viewDidLoad() {
        super.viewDidLoad()

        // present 타입의 경우 viewDidLoad에서 navigation을 설정
        self.navigationController?.configureNavigationBar(transparent: false, shadow: true)
    }

    deinit {
        // 메모리 해제되는지 확인
        print("[deinit] \(String(describing: type(of: self)))")
    }
}

// MARK: - ViewModelBindable
extension MembershipListViewController: ViewModelBindable {
    typealias ViewModel = MembershipListViewModel

    func bindViewModel(viewModel: ViewModel) {
        let dataSource = configureDataSource()

        let input = MembershipListViewModel.Input(
            viewWillAppear: rx.viewWillAppear.asDriver(), // 화면이 보여지기 전에
            viewWillLayoutSubviews: rx.viewWillLayoutSubviews.asDriver(), // subview의 layout이 갱신되기 전에
            selectedIndexPath: tableView.rx.itemSelected.asDriver().throttle(2), // tableView의 row를 눌렀을 때
            showAllMembershipBtnDidTap: showAllMembershipButton.rx.tap.asDriver(), // 전체 상품 보기 버튼 눌렀을 때
            closeBtnDidTap: closeButton.rx.tap.asDriver() // 닫기 버튼 눌렀을 때
        )

        let output = viewModel.build(input: input)

        // 화면이 보여지기 전에
        output
            .viewWillAppear
            .drive()
            .disposed(by: disposeBag)

        // subview의 layout이 갱신되기 전에
        output
            .viewWillLayoutSubviews
            .drive(onNext: { [weak self] in
                self?.changeLayoutSubviews()
            })
            .disposed(by: disposeBag)

        // post 정보를 불러와서 설정
        output
            .postItem
            .drive(onNext: { [weak self] postItem in
                self?.currentPostMembershipInfo.isHidden = false
                self?.currentPostTitleLabel.text = "\(postItem.title ?? "")"
            })
            .disposed(by: disposeBag)

        // 전체 상품 보기 버튼 눌렀을 때
        output
            .showAllMembershipBtnDidTap
            .drive(onNext: { [weak self] _ in
                guard let `self` = self else { return }
                self.tableView.setContentOffset(CGPoint(x: 0, y: -self.statusHeight-self.navigationHeight), animated: false)
                self.currentPostMembershipInfo.isHidden = true
                self.viewModel?.levelLimit.onNext(0)
            })
            .disposed(by: disposeBag)

        // 멤버십 목록을 tableView에 출력
        output
            .membershipList
            .do(onNext: { [weak self] _ in
                _ = self?.emptyView.subviews.map { $0.removeFromSuperview() }
                self?.emptyView.frame.size.height = 0
            })
            .drive { $0 }
            .map { [SectionModel(model: "membership", items: $0)] }
            .bind(to: tableView.rx.items(dataSource: dataSource))
            .disposed(by: disposeBag)

        // 구독자 정보 불러와서 설정
        output
            .subscriptionInfo
            .drive(onNext: { [weak self] subscriptionInfo in
                 guard
                    let level = subscriptionInfo?.membership?.level,
                    let membershipName = subscriptionInfo?.membership?.name,
                    level > 0
                else { return }

                self?.currentSubscriptionMembershipTitleLabel.text =
                    "\(LocalizationKey.str_membership_current_tier.localized(with: level)) -  \(LocalizationKey.str_membership_warning_current_membership.localized(with: membershipName))"
                self?.currentSubscriptionMembershipView.isHidden = false
            })
            .disposed(by: disposeBag)

        output
            .projectInfo
            .drive(onNext: { [weak self] projectInfo in
                if let thumbnail = projectInfo.thumbnail {
                    let thumbnailWithIC = "\(thumbnail)?w=720&h=720&quality=80&output=webp"
                    if let url = URL(string: thumbnailWithIC) {
                        self?.thumbnailImageView.sd_setImageWithFade(with: url, placeholderImage: #imageLiteral(resourceName: "img-dummy-square-500-x-500"), completed: nil)
                    }
                } else {
                    self?.thumbnailImageView.image = #imageLiteral(resourceName: "img-dummy-square-500-x-500")
                }
                self?.writerLabel.text = projectInfo.user?.username ?? ""
            })
            .disposed(by: disposeBag)

        // emptyView 출력
        output
            .embedEmptyViewController
            .drive(onNext: { [weak self] in
                self?.embedCustomEmptyViewController(style: $0)
            })
            .disposed(by: disposeBag)

        // tableView의 row를 선택할 때
        output
            .selectedIndexPath
            .drive(onNext: { [weak self] indexPath in
                let (membership, subscriptionInfo) = (dataSource[indexPath].membership, dataSource[indexPath].subscriptionInfo)
                if membership.sponsorLimit == 0 { return } // 판매종료
                if let sponsorLimit = membership.sponsorLimit,
                    let sponsorCount = membership.sponsorCount,
                    sponsorLimit <= sponsorCount { return } // 판매종료
                if let subscriptionLevel = subscriptionInfo?.membership?.level,
                    let membershipLevel = membership.level,
                    membershipLevel > 0 && membershipLevel <= subscriptionLevel {
                    return
                } // 구독 중

                self?.openView(type: .purchaseMembership(uri: self?.viewModel?.uri ?? "", selectedMembership: membership), openType: .push)
            })
            .disposed(by: disposeBag)

        // 로그인 화면 출력
        output
            .openSignInViewController
            .map { .signIn }
            .drive(onNext: { [weak self] in
                self?.openView(type: $0, openType: .swipePresent)
            })
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
                Toast.loadingActivity(false)
                self?.showPopup(
                    title: LocalizationKey.popup_title_network_error.localized(),
                    message: LocalizationKey.msg_api_internal_server_error.localized(),
                    action: [LocalizationKey.retry.localized(), LocalizationKey.cancel.localized()]) { [weak self] in
                        self?.viewModel?.loadRetryTrigger.onNext(())
                    }
            })
            .disposed(by: disposeBag)

        // 화면을 닫음
        output
            .dismissViewController
            .drive(onNext: { [weak self] message in
                self?.dismiss(animated: true)
            })
            .disposed(by: disposeBag)
    }
}

// MARK: - DataSource
extension MembershipListViewController {
    private func configureDataSource() -> RxTableViewSectionedReloadDataSource<SectionModel<String, MembershipListTableViewCellModel>> {
        return RxTableViewSectionedReloadDataSource<SectionModel<String, MembershipListTableViewCellModel>>(
            // cell 설정
            configureCell: { dataSource, tableView, indexPath, model in
                let cell: MembershipListTableViewCell = tableView.dequeueReusableCell(forIndexPath: indexPath)
                cell.configure(with: model)
                return cell
        })
    }
}

// MARK: - Private Method
extension MembershipListViewController {
    // Pad에서 가로/세로모드 변경 시 header size 변경
    private func changeLayoutSubviews() {
        if let headerView = tableView.tableHeaderView {
            let height = headerView.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize).height
            var headerFrame = headerView.frame

            // Comparison necessary to avoid infinite loop
            if height != headerFrame.size.height {
                headerFrame.size.height = height
                headerView.frame = headerFrame
                tableView.tableHeaderView = headerView
            }
        }
    }

    // emptyView를 embed
    private func embedCustomEmptyViewController(style: CustomEmptyViewStyle) {
        _ = emptyView.subviews.map { $0.removeFromSuperview() }
        emptyView.frame.size.height = 350
        let vc = CustomEmptyViewController.make(style: style)
        embed(vc, to: emptyView)
    }
}
