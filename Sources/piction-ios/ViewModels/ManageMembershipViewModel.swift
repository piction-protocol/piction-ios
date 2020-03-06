//
//  ManageMembershipViewModel.swift
//  piction-ios
//
//  Created by jhseo on 2019/11/22.
//  Copyright © 2019 Piction Network. All rights reserved.
//

import RxSwift
import RxCocoa
import PictionSDK

// 현재 사용하지 않는 화면입니다. (에디터 기능 지원안함)

// MARK: - ViewModel
final class ManageMembershipViewModel: InjectableViewModel {

    typealias Dependency = (
        FirebaseManagerProtocol,
        UpdaterProtocol,
        String,
        Int?
    )

    private let firebaseManager: FirebaseManagerProtocol
    private let updater: UpdaterProtocol
    let uri: String
    let membershipId: Int?

    var loadRetryTrigger = PublishSubject<Void>()

    init(dependency: Dependency) {
        (firebaseManager, updater, uri, membershipId) = dependency
    }
}

// MARK: - Input & Output
extension ManageMembershipViewModel {
    struct Input {
        let viewWillAppear: Driver<Void>
        let selectedIndexPath: Driver<IndexPath>
        let createBtnDidTap: Driver<Void>
        let deleteMembership: Driver<(String, Int)>
        let closeBtnDidTap: Driver<Void>
    }
    struct Output {
        let viewWillAppear: Driver<Void>
        let membershipList: Driver<[MembershipModel]>
        let selectedIndexPath: Driver<IndexPath>
        let openCreateMembershipViewController: Driver<String>
        let showErrorPopup: Driver<Void>
        let activityIndicator: Driver<Bool>
        let dismissViewController: Driver<Void>
        let toastMessage: Driver<String>
    }
}

// MARK: - ViewModel Build
extension ManageMembershipViewModel {
    func build(input: Input) -> Output {
        let (firebaseManager, updater, uri, membershipId) = (self.firebaseManager, self.updater, self.uri, self.membershipId)

        // 화면이 보여지기 전에
        let viewWillAppear = input.viewWillAppear
            .do(onNext: { _ in
                // analytics screen event
                firebaseManager.screenName("Membership관리_\(uri)_\(membershipId ?? 0)")
            })

        // 최초 진입 시
        let initialLoad = input.viewWillAppear
            .asObservable()
            .take(1)
            .asDriver(onErrorDriveWith: .empty())

        // 새로고침 필요 시
        let loadRetry = loadRetryTrigger
            .asDriver(onErrorDriveWith: .empty())

        // 컨텐츠의 내용 갱신 필요 시
        let refreshContent = updater.refreshContent
            .asDriver(onErrorDriveWith: .empty())

        // 최초진입 시, 새로고침 시, 컨텐츠의 내용 갱신 필요 시
        let loadPage = Driver.merge(initialLoad, loadRetry, refreshContent)

        // 최초진입 시, 새로고침 시, 컨텐츠의 내용 갱신 필요 시
        // 멤버십 목록 호출
        let membershipListAction = loadPage
            .map { MembershipAPI.all(uri: uri) }
            .map(PictionSDK.rx.requestAPI)
            .flatMap(Action.makeDriver)

        // 멤버십 목록 호출 성공 시
        let membershipListSuccess = membershipListAction.elements
            .map { try? $0.map(to: [MembershipModel].self) }
            .flatMap(Driver.from)

        // 멤버십 목록 호출 에러 시
        let membershipListError = membershipListAction.error
            .map { _ in Void() }

        // 멤버십 생성
        let openCreateMembershipViewController = input.createBtnDidTap
            .map { uri }

        // 멤버십 삭제 호출
        let deleteAction = input.deleteMembership
            .map { MembershipAPI.delete(uri: $0, membershipId: $1) }
            .map(PictionSDK.rx.requestAPI)
            .flatMap(Action.makeDriver)

        // 멤버십 삭제 성공 시
        let deleteSuccess = deleteAction.elements
            .map { _ in LocalizationKey.msg_delete_membership_success.localized() }
            .do(onNext: { _ in
                updater.refreshContent.onNext(())
            })

        // 멤버십 삭제 에러 시
        let deleteError = deleteAction.error
            .map { $0 as? ErrorType }
            .map { $0?.message }
            .flatMap(Driver.from)

        // 에러 팝업 출력
        let showErrorPopup = membershipListError

        // 로딩 뷰
        let activityIndicator = membershipListAction.isExecuting

        // 닫기버튼 누르면 dismiss
        let dismissViewController = input.closeBtnDidTap

        // 토스트 메시지
        let toastMessage = Driver.merge(
            deleteSuccess,
            deleteError)

        return Output(
            viewWillAppear: viewWillAppear,
            membershipList: membershipListSuccess,
            selectedIndexPath: input.selectedIndexPath,
            openCreateMembershipViewController: openCreateMembershipViewController,
            showErrorPopup: showErrorPopup,
            activityIndicator: activityIndicator,
            dismissViewController: dismissViewController,
            toastMessage: toastMessage
        )
    }
}
