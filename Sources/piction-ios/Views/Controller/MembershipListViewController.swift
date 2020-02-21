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
        self.navigationController?.configureNavigationBar(transparent: false, shadow: true)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        if let headerView = tableView.tableHeaderView {
            let height = headerView.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize).height
            var headerFrame = headerView.frame

            //Comparison necessary to avoid infinite loop
            if height != headerFrame.size.height {
                headerFrame.size.height = height
                headerView.frame = headerFrame
                tableView.tableHeaderView = headerView
            }
        }
    }

    private func configureDataSource() -> RxTableViewSectionedReloadDataSource<SectionModel<String, MembershipListTableViewCellModel>> {
        return RxTableViewSectionedReloadDataSource<SectionModel<String, MembershipListTableViewCellModel>>(
            configureCell: { dataSource, tableView, indexPath, model in
                let cell: MembershipListTableViewCell = tableView.dequeueReusableCell(forIndexPath: indexPath)
                cell.configure(with: model)
                return cell
        })
    }

    private func embedCustomEmptyViewController(style: CustomEmptyViewStyle) {
        _ = emptyView.subviews.map { $0.removeFromSuperview() }
        emptyView.frame.size.height = 350
        let vc = CustomEmptyViewController.make(style: style)
        embed(vc, to: emptyView)
    }
}

extension MembershipListViewController: ViewModelBindable {
    typealias ViewModel = MembershipListViewModel

    func bindViewModel(viewModel: ViewModel) {
        let dataSource = configureDataSource()

        let input = MembershipListViewModel.Input(
            viewWillAppear: rx.viewWillAppear.asDriver(),
            selectedIndexPath: tableView.rx.itemSelected.asDriver().throttle(2),
            showAllMembershipBtnDidTap: showAllMembershipButton.rx.tap.asDriver(),
            closeBtnDidTap: closeButton.rx.tap.asDriver()
        )

        let output = viewModel.build(input: input)

        output
            .viewWillAppear
            .drive(onNext: { [weak self] in
                self?.navigationController?.configureNavigationBar(transparent: false, shadow: true)
            })
            .disposed(by: disposeBag)

        output
            .postItem
            .drive(onNext: { [weak self] postItem in
                self?.currentPostMembershipInfo.isHidden = false
                self?.currentPostTitleLabel.text = "\(postItem.title ?? "")"
            })
            .disposed(by: disposeBag)

        output
            .showAllMembershipBtnDidTap
            .drive(onNext: { [weak self] _ in
                guard let `self` = self else { return }
                self.tableView.setContentOffset(CGPoint(x: 0, y: -self.statusHeight-self.navigationHeight), animated: false)
                self.currentPostMembershipInfo.isHidden = true
                self.viewModel?.levelLimit.onNext(0)
            })
            .disposed(by: disposeBag)

        output
            .membershipTableItems
            .do(onNext: { [weak self] _ in
                _ = self?.emptyView.subviews.map { $0.removeFromSuperview() }
                self?.emptyView.frame.size.height = 0
            })
            .drive { $0 }
            .map { [SectionModel(model: "membership", items: $0)] }
            .bind(to: tableView.rx.items(dataSource: dataSource))
            .disposed(by: disposeBag)

        output
            .subscriptionInfo
            .drive(onNext: { [weak self] subscriptionInfo in
                if let level = subscriptionInfo?.membership?.level,
                    let membershipName = subscriptionInfo?.membership?.name,
                    level > 0 {
                    self?.currentSubscriptionMembershipTitleLabel.text =
                        "\(LocalizationKey.str_membership_current_tier.localized(with: level)) -  \(LocalizationKey.str_membership_warning_current_membership.localized(with: membershipName))"
                    self?.currentSubscriptionMembershipView.isHidden = false
                }
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

        output
            .embedEmptyViewController
            .drive(onNext: { [weak self] style in
                guard let `self` = self else { return }
                self.embedCustomEmptyViewController(style: style)
            })
            .disposed(by: disposeBag)

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

                self?.openPurchaseMembershipViewController(uri: self?.viewModel?.uri ?? "", selectedMembership: membership)
            })
            .disposed(by: disposeBag)

        output
            .openSignInViewController
            .drive(onNext: { [weak self] _ in
                self?.openSignInViewController()
            })
            .disposed(by: disposeBag)

        output
            .activityIndicator
            .loadingActivity()
            .disposed(by: disposeBag)

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

        output
            .dismissViewController
            .drive(onNext: { [weak self] message in
                self?.dismiss(animated: true)
            })
            .disposed(by: disposeBag)
    }
}
