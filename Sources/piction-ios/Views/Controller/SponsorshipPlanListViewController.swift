//
//  SponsorshipPlanListViewController.swift
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

final class SponsorshipPlanListViewController: UIViewController {
    var disposeBag = DisposeBag()

    @IBOutlet weak var thumbnailImageView: UIImageView!
    @IBOutlet weak var writerLabel: UILabel!
    @IBOutlet weak var currentSubscriptionSponsorshipPlanTitleLabel: UILabel!
    @IBOutlet weak var currentSubscriptionSponsorshipPlanView: UIView!
    @IBOutlet weak var showAllSponsorshipPlanButton: UIButton!
    @IBOutlet weak var currentPostSponsorshipPlanInfo: UIView!
    @IBOutlet weak var currentPostTitleLabel: UILabel!
    @IBOutlet weak var closeButton: UIBarButtonItem!
    @IBOutlet weak var tableView: UITableView!

    private let subscribeFree = PublishSubject<Void>()

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

    private func configureDataSource() -> RxTableViewSectionedReloadDataSource<SectionModel<String, SponsorshipPlanListTableViewCellModel>> {
        return RxTableViewSectionedReloadDataSource<SectionModel<String, SponsorshipPlanListTableViewCellModel>>(
            configureCell: { dataSource, tableView, indexPath, model in
                let cell: SponsorshipPlanListTableViewCell = tableView.dequeueReusableCell(forIndexPath: indexPath)
                cell.configure(with: model)
                return cell
        })
    }
}

extension SponsorshipPlanListViewController: ViewModelBindable {
    typealias ViewModel = SponsorshipPlanListViewModel

    func bindViewModel(viewModel: ViewModel) {
        let dataSource = configureDataSource()

        let input = SponsorshipPlanListViewModel.Input(
            viewWillAppear: rx.viewWillAppear.asDriver(),
            selectedIndexPath: tableView.rx.itemSelected.asDriver().throttle(2),
            showAllSponsorshipPlanBtnDidTap: showAllSponsorshipPlanButton.rx.tap.asDriver(),
            subscribeFreeBtnDidTap: subscribeFree.asDriver(onErrorDriveWith: .empty()),
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
                self?.currentPostSponsorshipPlanInfo.isHidden = false
                self?.currentPostTitleLabel.text = "\(postItem.title ?? "")"
            })
            .disposed(by: disposeBag)

        output
            .showAllSponsorshipPlanBtnDidTap
            .drive(onNext: { [weak self] _ in
                guard let `self` = self else { return }
                self.tableView.setContentOffset(CGPoint(x: 0, y: -self.statusHeight-self.navigationHeight), animated: false)
                self.currentPostSponsorshipPlanInfo.isHidden = true
                self.viewModel?.levelLimit.onNext(0)
            })
            .disposed(by: disposeBag)

        output
            .sponsorshipPlanTableItems
            .drive { $0 }
            .map { [SectionModel(model: "sponsorshipPlan", items: $0)] }
            .bind(to: tableView.rx.items(dataSource: dataSource))
            .disposed(by: disposeBag)

        output
            .subscriptionInfo
            .drive(onNext: { [weak self] subscriptionInfo in
                if let level = subscriptionInfo?.plan?.level,
                    let sponsorshipPlanName = subscriptionInfo?.plan?.name,
                    level > 0 {
                    self?.currentSubscriptionSponsorshipPlanTitleLabel.text =
                        "\(LocalizationKey.str_sponsorship_plan_current_tier.localized(with: level)) -  \(LocalizationKey.str_sponsorship_plan_warning_current_sponsorship_plan.localized(with: sponsorshipPlanName))"
                    self?.currentSubscriptionSponsorshipPlanView.isHidden = false
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
            .selectedIndexPath
            .drive(onNext: { [weak self] indexPath in
                let (sponsorshipPlan, subscriptionInfo) = (dataSource[indexPath].sponsorshipPlan, dataSource[indexPath].subscriptionInfo)
                if sponsorshipPlan.sponsorshipLimit == 0 { return } // 판매종료
                if let sponsorshipLimit = sponsorshipPlan.sponsorshipLimit,
                    let sponsorshipCount = sponsorshipPlan.sponsorshipCount,
                    sponsorshipLimit <= sponsorshipCount { return } // 판매종료
                if let subscriptionLevel = subscriptionInfo?.plan?.level,
                    let sponsorshipPlanLevel = sponsorshipPlan.level,
                    sponsorshipPlanLevel > 0 && sponsorshipPlanLevel <= subscriptionLevel { return } // 구독 중

                if let sponsorshipPlanLevel = sponsorshipPlan.level,
                    sponsorshipPlanLevel == 0 {
                    self?.subscribeFree.onNext(())
                } else {
                    self?.openPurchaseSponsorshipPlanViewController(uri: self?.viewModel?.uri ?? "", selectedSponsorshipPlan: sponsorshipPlan)
                }
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
                    action: LocalizationKey.retry.localized()) { [weak self] in
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

        output
            .toastMessage
            .showToast()
            .disposed(by: disposeBag)
    }
}