//
//  ProjectDetailViewController.swift
//  piction-ios
//
//  Created by jhseo on 2020/02/21.
//  Copyright © 2020 Piction Network. All rights reserved.
//

import UIKit
import RxSwift
import RxCocoa
import ViewModelBindable
import RxDataSources
import PictionSDK

enum ProjectDetailButtonStyle {
    case dimmed
    case `default`

    var backgroundColor: UIColor {
        switch self {
        case .default:
            return .white
        case .dimmed:
            return .pictionLightGray
        }
    }

    var textColor: UIColor {
        switch self {
        case .default:
            return .pictionDarkGray
        case .dimmed:
            return .pictionGray
        }
    }

    var borderColor: CGColor {
        switch self {
        case .default:
            return UIColor.pictionDarkGray.cgColor
        default:
            return UIColor.clear.cgColor
        }
    }

    var borderWidth: CGFloat {
        return self == .default ? 2 : 0
    }
}

final class ProjectDetailViewController: UIViewController {
    var disposeBag = DisposeBag()

    @IBOutlet weak var projectDetailContainerView: UIView!
    @IBOutlet weak var categoryCollectionView: UICollectionView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var sponsorCountLabel: UILabel!
    @IBOutlet weak var profileImageView: UIImageViewExtension!
    @IBOutlet weak var usernameLabel: UILabel!
    @IBOutlet weak var loginIdLabel: UILabel!
    @IBOutlet weak var subscriptionButton: UIButtonExtension!
    @IBOutlet weak var membershipButton: UIButtonExtension!
    @IBOutlet weak var creatorProfileButton: UIButton!

    private let cancelSubscription = PublishSubject<Void>()

    private func configureDataSource() -> RxCollectionViewSectionedReloadDataSource<SectionModel<String, CategoryModel>> {
        return RxCollectionViewSectionedReloadDataSource<SectionModel<String, CategoryModel>>(
            configureCell: { dataSource, collectionView, indexPath, model in
                let cell: ProjectInfoCategoryCollectionViewCell = collectionView.dequeueReusableCell(forIndexPath: indexPath)
                cell.configure(with: model)
                return cell
        })
    }
}

extension ProjectDetailViewController: ViewModelBindable {
    typealias ViewModel = ProjectDetailViewModel

    func bindViewModel(viewModel: ViewModel) {
        let dataSource = configureDataSource()

        categoryCollectionView.rx.setDelegate(self)
            .disposed(by: disposeBag)

        let input = ProjectDetailViewModel.Input(
            viewWillAppear: rx.viewWillAppear.asDriver(),
            selectedIndexPath: categoryCollectionView.rx.itemSelected.asDriver(),
            subscriptionBtnDidTap: subscriptionButton.rx.tap.asDriver(),
            cancelSubscriptionBtnDidTap: cancelSubscription.asDriver(onErrorDriveWith: .empty()),
            membershipBtnDidTap: membershipButton.rx.tap.asDriver(),
            creatorProfileBtnDidTap: creatorProfileButton.rx.tap.asDriver()
        )

        let output = viewModel.build(input: input)

        output
            .selectedIndexPath
            .drive(onNext: { [weak self] indexPath in
                guard let categoryId = dataSource[indexPath].id else { return }
                self?.openCategorizedProjectViewController(id: categoryId)
            })
            .disposed(by: disposeBag)

        output
            .projectInfo
            .drive { $0 }
            .map { [SectionModel(model: "category", items: $0.categories ?? [])] }
            .bind(to: categoryCollectionView.rx.items(dataSource: dataSource))
            .disposed(by: disposeBag)

        output
            .projectInfo
            .map { ($0.categories?.isEmpty ?? true) }
            .drive(categoryCollectionView.rx.isHidden)
            .disposed(by: disposeBag)

        output
            .projectInfo
            .drive(onNext: { [weak self] projectInfo in
                guard
                    let title = projectInfo.title,
                    let username = projectInfo.user?.username,
                    let loginId = projectInfo.user?.loginId,
                    let sponsorCount = projectInfo.sponsorCount
                else { return }

                self?.titleLabel.text = title
                self?.usernameLabel.text = username
                self?.loginIdLabel.text = "@\(loginId)"

                if let profileImage = projectInfo.user?.picture {
                    let userPictureWithIC = "\(profileImage)?w=240&h=240&quality=80&output=webp"
                    if let url = URL(string: userPictureWithIC) {
                        self?.profileImageView.sd_setImageWithFade(with: url, placeholderImage: #imageLiteral(resourceName: "img-dummy-square-500-x-500"), completed: nil)
                    }
                } else {
                    self?.profileImageView.image = #imageLiteral(resourceName: "img-dummy-square-500-x-500")
                }

                self?.sponsorCountLabel.text =  LocalizationKey.str_subs_count_plural.localized(with: sponsorCount.commaRepresentation)
            })
            .disposed(by: disposeBag)

        output
            .sponsoredMembership
            .drive(onNext: { [weak self] sponsoredMembership in
                guard let `self` = self else { return }
                guard let membershipLevel = sponsoredMembership?.membership?.level else {
                    self.configureButtonStyle(button: self.subscriptionButton, style: .default)
                    self.subscriptionButton.setTitle("구독", for: .normal)
                    self.membershipButton.setTitle("후원하기", for: .normal)
                    return
                }
                self.configureButtonStyle(button: self.subscriptionButton, style: .dimmed)
                self.subscriptionButton.setTitle("구독 중", for: .normal)

                if membershipLevel == 0 {
                    self.membershipButton.setTitle("후원하기", for: .normal)
                } else {
//                    self.subscriptionButton.isHidden = true
                    self.membershipButton.setTitle("내 후원 정보", for: .normal)
                }
            })
            .disposed(by: disposeBag)

        output
            .membershipBtnHidden
            .drive(onNext: { [weak self] status in
                self?.membershipButton.isHidden = status
            })
            .disposed(by: disposeBag)

        output
            .isWriter
            .drive(onNext: { [weak self] status in
                self?.subscriptionButton.isHidden = status
            })
            .disposed(by: disposeBag)

        output
            .openCancelSubscriptionPopup
            .drive(onNext: { [weak self] in
                self?.openCancelSubscriptionPopup()
            })
            .disposed(by: disposeBag)

        output
            .openNoCancellationSubscriptionPopup
            .drive(onNext: { [weak self] in
                self?.openNoCancellationSubscriptionPopup()
            })
            .disposed(by: disposeBag)

        output
            .openMembershipListViewController
            .drive(onNext: { [weak self] uri in
                self?.openMembershipListViewController(uri: uri)
            })
            .disposed(by: disposeBag)

        output
            .openCreatorProfileViewController
            .drive(onNext: { [weak self] loginId in
                self?.openCreatorProfileViewController(loginId: loginId)
            })
            .disposed(by: disposeBag)

        output
            .openSignInViewController
            .drive(onNext: { [weak self] in
                self?.openSignInViewController()
            })
            .disposed(by: disposeBag)

        output
            .toastMessage
            .showToast()
            .disposed(by: disposeBag)
    }
}

extension ProjectDetailViewController {
    private func configureButtonStyle(button: UIButton, style: ProjectDetailButtonStyle) {
        button.layer.borderWidth = style.borderWidth
        button.layer.borderColor = style.borderColor
        button.backgroundColor = style.backgroundColor
        button.setTitleColor(style.textColor, for: .normal)
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

    private func openNoCancellationSubscriptionPopup() {
        let alertController = UIAlertController(title: nil, message: LocalizationKey.msg_no_cancellation_subscription.localized(), preferredStyle: .alert)
        let confirmButton = UIAlertAction(title: LocalizationKey.confirm.localized(), style: .default)

        alertController.addAction(confirmButton)

        self.present(alertController, animated: true, completion: nil)
    }

    private func openSharePopup(projectInfo: ProjectModel) {
        guard
            let uri = projectInfo.uri,
            let title = projectInfo.title
        else { return }

        let stagingPath = AppInfo.isStaging ? "staging." : ""

        let url = "\(title) - Piction\nhttps://\(stagingPath)piction.network/project/\(uri)"

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

    private func openManagePopup(uri: String) {
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
}

extension ProjectDetailViewController: UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        if let cell = collectionView.dataSource?.collectionView(collectionView, cellForItemAt: indexPath) as? ProjectInfoCategoryCollectionViewCell {
            let text = cell.categoryLabel.text ?? ""
            let cellWidth = text.size(withAttributes:[.font: UIFont.systemFont(ofSize: 12.0)]).width + 35.0
            return CGSize(width: cellWidth, height: 24.0)
        }
        return .zero
    }
}
