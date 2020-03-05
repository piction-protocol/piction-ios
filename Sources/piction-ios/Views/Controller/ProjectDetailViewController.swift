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

// MARK: - ProjectDetailViewDelegate
protocol ProjectDetailViewDelegate: class {
    func layoutIfNeeded()
}

// MARK: - UIViewController
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
    @IBOutlet weak var subscriptionUserButton: UIButton!

    weak var delegate: ProjectDetailViewDelegate?

    // 구독 취소 시 출력되는 팝업에서 확인버튼을 눌렀을 때
    private let cancelSubscription = PublishSubject<Void>()

    deinit {
        // 메모리 해제되는지 확인
        print("[deinit] \(String(describing: type(of: self)))")
    }
}

// MARK: - ViewModelBindable
extension ProjectDetailViewController: ViewModelBindable {
    typealias ViewModel = ProjectDetailViewModel

    func bindViewModel(viewModel: ViewModel) {
        let dataSource = configureDataSource()

        let input = ProjectDetailViewModel.Input(
            viewWillAppear: rx.viewWillAppear.asDriver(), // 화면이 보여지기 전에
            selectedIndexPath: categoryCollectionView.rx.itemSelected.asDriver(), // collectionView의 item을 눌렀을 때
            subscriptionBtnDidTap: subscriptionButton.rx.tap.asDriver(), // 구독 버튼을 눌렀을 때
            cancelSubscriptionBtnDidTap: cancelSubscription.asDriver(onErrorDriveWith: .empty()), // 구독 취소 팝업의 확인 버튼을 눌렀을 때
            membershipBtnDidTap: membershipButton.rx.tap.asDriver(), // 후원 버튼을 눌렀을 때
            creatorProfileBtnDidTap: creatorProfileButton.rx.tap.asDriver(), // Creator 정보를 눌렀을 때
            subscriptionUserBtnDidTap: subscriptionUserButton.rx.tap.asDriver()
        )

        let output = viewModel.build(input: input)

        // Category 항목을 눌렀을 때 CategoriedProject 화면으로 Push
        output
            .selectedIndexPath
            .map { dataSource[$0].id }
            .flatMap(Driver.from)
            .map { .categorizedProject(id: $0) }
            .drive(onNext: { [weak self] in
                self?.openView(type: $0, openType: .push)
            })
            .disposed(by: disposeBag)

        // Project 정보를 받아와서 Category를 collectionView에 출력
        output
            .projectInfo
            .drive { $0 }
            .map { [SectionModel(model: "category", items: $0.categories ?? [])] }
            .bind(to: categoryCollectionView.rx.items(dataSource: dataSource))
            .disposed(by: disposeBag)

        // category가 없거나 status가 HIDDEN이면 category를 보여주지 않음
        output
            .projectInfo
            .map { ($0.status ?? "" == "HIDDEN") || ($0.categories?.isEmpty ?? true) }
            .drive(categoryCollectionView.rx.isHidden)
            .disposed(by: disposeBag)

        // Project 정보를 받아와서 프로필 이미지, title 등의 값을 설정
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

        // 구독하거나 후원한 멤버십이 있다면 구독/후원버튼 스타일을 변경
        output
            .sponsoredMembership
            .drive(onNext: { [weak self] sponsoredMembership in
                guard let `self` = self else { return }
                guard let sponsoredMembershipLevel = sponsoredMembership?.membership?.level else {
                    // 구독하거나 후원한 멤버십이 없으면 기본 타입
                    self.configureButtonStyle(button: self.subscriptionButton, style: .default)
                    self.subscriptionButton.setTitle(LocalizationKey.tab_subscription.localized(), for: .normal)
                    self.membershipButton.setTitle(LocalizationKey.btn_subs_membership.localized(), for: .normal)
                    return
                }
                // 구독하거나 후원한 멤버십이 있으면 dimmed 처리
                self.configureButtonStyle(button: self.subscriptionButton, style: .dimmed)
                self.subscriptionButton.setTitle(LocalizationKey.str_project_subscribing.localized(), for: .normal)

                // 후원하기 버튼 텍스트
                if sponsoredMembershipLevel == 0 { // 구독했으면
                   // 후원하기
                    self.membershipButton.setTitle(LocalizationKey.btn_subs_membership.localized(), for: .normal)
                } else { // 후원했으면
                    // 내 후원 정보
                    self.membershipButton.setTitle(LocalizationKey.btn_subs_my_membership_info.localized(), for: .normal)
                }
            })
            .disposed(by: disposeBag)

        // 멤버십이 없거나 본인의 project이면 후원버튼을 숨김
        output
            .membershipBtnHidden
            .drive(onNext: { [weak self] status in
                self?.membershipButton.isHidden = status
                self?.delegate?.layoutIfNeeded()
            })
            .disposed(by: disposeBag)

        // 본인의 project이면 구독버튼을 숨김
        output
            .isWriter
            .drive(subscriptionButton.rx.isHidden)
            .disposed(by: disposeBag)

        // 구독취소 팝업을 출력
        output
            .openCancelSubscriptionPopup
            .drive(onNext: { [weak self] in
                self?.openCancelSubscriptionPopup()
            })
            .disposed(by: disposeBag)

        // 멤버십 후원 중일 경우 구독취소 불가 팝업 출력
        output
            .openNoCancellationSubscriptionPopup
            .drive(onNext: { [weak self] in
                self?.openNoCancellationSubscriptionPopup()
            })
            .disposed(by: disposeBag)

        // 후원버튼 누르면 후원목록을 present
        output
            .openMembershipListViewController
            .map { .membershipList(uri: $0) }
            .drive(onNext: { [weak self] in
                self?.openView(type: $0, openType: .present)
            })
            .disposed(by: disposeBag)

        // 크리에이터를 누르면 CreatorProfile 화면을 push
        output
            .openCreatorProfileViewController
            .map { .creatorProfile(loginId: $0) }
            .drive(onNext: { [weak self] in
                self?.openView(type: $0, openType: .push)
            })
            .disposed(by: disposeBag)

        // 로그인 상태가 아니면 구독/후원버튼 누를 때 로그인 화면을 출력
        output
            .openSignInViewController
            .map { .signIn }
            .drive(onNext: { [weak self] in
                self?.openView(type: $0, openType: .swipePresent)
            })
            .disposed(by: disposeBag)

        // 구독자 눌렀을 때
        output
            .openSubscriptionUserViewController
            .map { .subscriptionUser(uri: $0) } // 구독자 목록 화면을 출력
            .drive(onNext: { [weak self] in
                self?.openView(type: $0, openType: .swipePresent)
            })
            .disposed(by: disposeBag)

        // 토스트 메시지 출력
        output
            .toastMessage
            .showToast()
            .disposed(by: disposeBag)
    }
}

// MARK: - UICollectionViewDelegateFlowLayout
extension ProjectDetailViewController: UICollectionViewDelegateFlowLayout {
    // Category text에 따라 cell의 크기 조정
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        if let cell = collectionView.dataSource?.collectionView(collectionView, cellForItemAt: indexPath) as? ProjectInfoCategoryCollectionViewCell {
            let text = cell.categoryLabel.text ?? ""
            let cellWidth = text.size(withAttributes:[.font: UIFont.systemFont(ofSize: 12.0)]).width + 35.0
            return CGSize(width: cellWidth, height: 24.0)
        }
        return .zero
    }
}

// MARK: - DataSource
extension ProjectDetailViewController {
    private func configureDataSource() -> RxCollectionViewSectionedReloadDataSource<SectionModel<String, CategoryModel>> {
        return RxCollectionViewSectionedReloadDataSource<SectionModel<String, CategoryModel>>(
            // cell 설정
            configureCell: { dataSource, collectionView, indexPath, model in
                let cell: ProjectInfoCategoryCollectionViewCell = collectionView.dequeueReusableCell(forIndexPath: indexPath)
                cell.configure(with: model)
                return cell
        })
    }
}

// MARK: - Private Method
extension ProjectDetailViewController {

    // ProjectDetailButtonStyle에 따라 버튼 스타일 변경
    private func configureButtonStyle(button: UIButton, style: ProjectDetailButtonStyle) {
        button.layer.borderWidth = style.borderWidth
        button.layer.borderColor = style.borderColor
        button.backgroundColor = style.backgroundColor
        button.setTitleColor(style.textColor, for: .normal)
    }

    // 구독 취소 팝업
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

    // 구독취소가 안된다는 팝업 출력
    private func openNoCancellationSubscriptionPopup() {
        let alertController = UIAlertController(title: nil, message: LocalizationKey.msg_no_cancellation_subscription.localized(), preferredStyle: .alert)
        let confirmButton = UIAlertAction(title: LocalizationKey.confirm.localized(), style: .default)

        alertController.addAction(confirmButton)

        self.present(alertController, animated: true, completion: nil)
    }

    // 공유 팝업 출력
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

    // 사용안함 - 크리에이터용 관리 팝업
    private func openManagePopup(uri: String) {
        let alertController = UIAlertController(
        title: nil,
        message: nil,
        preferredStyle: UIAlertController.Style.actionSheet)

        let manageProjectAction = UIAlertAction(
            title: "프로젝트 관리",
            style: UIAlertAction.Style.default,
            handler: { [weak self] action in
                self?.openView(type: .createProject(uri: uri), openType: .push)
            })

        let manageSeriesAction = UIAlertAction(
            title: "시리즈 관리",
            style: UIAlertAction.Style.default,
            handler: { [weak self] action in
                self?.openView(type: .manageSeries(uri: uri), openType: .swipePresent)
            })

        let manageMembershipAction = UIAlertAction(
            title: "Membership 관리",
            style: UIAlertAction.Style.default,
            handler: { [weak self] action in
                self?.openView(type: .manageMembership(uri: uri), openType: .swipePresent)
            })

        let cancelAction = UIAlertAction(
            title: LocalizationKey.cancel.localized(),
            style: UIAlertAction.Style.cancel,
            handler:{ action in
            })

        alertController.addAction(manageProjectAction)
        alertController.addAction(manageSeriesAction)
        alertController.addAction(manageMembershipAction)
        alertController.addAction(cancelAction)

        present(alertController, animated: true, completion: nil)
    }
}

// MARK: - ProjectDetailButtonStyle
extension ProjectDetailViewController {
    enum ProjectDetailButtonStyle {
        case dimmed
        case `default`

        // 배경 색
        var backgroundColor: UIColor {
            switch self {
            case .default:
                return .white
            case .dimmed:
                return .pictionLightGray
            }
        }

        // 글자 색
        var textColor: UIColor {
            switch self {
            case .default:
                return .pictionDarkGray
            case .dimmed:
                return .pictionGray
            }
        }

        // 테두리 색
        var borderColor: CGColor {
            switch self {
            case .default:
                return UIColor.pictionDarkGray.cgColor
            default:
                return UIColor.clear.cgColor
            }
        }

        // 테두리 굵기
        var borderWidth: CGFloat {
            return self == .default ? 2 : 0
        }
    }
}
