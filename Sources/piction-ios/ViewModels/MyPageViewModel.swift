//
//  MyPageViewModel.swift
//  PictionView
//
//  Created by jhseo on 19/06/2019.
//  Copyright © 2019 Piction Network. All rights reserved.
//

import RxSwift
import RxCocoa
import RxDataSources
import PictionSDK
import LocalAuthentication

// MARK: - MyPageSection
enum MyPageSection {
    case header(title: String)
    case pushType(title: String)
    case switchType(title: String, key: String)
    case presentType(title: String, align: NSTextAlignment)
    case underline
}

// MARK: - ViewModel
final class MyPageViewModel: InjectableViewModel {

    typealias Dependency = (
        FirebaseManagerProtocol,
        UpdaterProtocol,
        KeychainManagerProtocol
    )

    private let firebaseManager: FirebaseManagerProtocol
    private let updater: UpdaterProtocol
    private let keychainManager: KeychainManagerProtocol

    var loadRetryTrigger = PublishSubject<Void>()

    init(dependency: Dependency) {
        (firebaseManager, updater, keychainManager) = dependency
    }
}

// MARK: - Input & Output
extension MyPageViewModel {
    struct Input {
        let viewWillAppear: Driver<Void>
        let viewWillLayoutSubviews: Driver<Void>
        let selectedIndexPath: Driver<IndexPath>
        let logout: Driver<Void>
        let refreshControlDidRefresh: Driver<Void>
    }
    struct Output {
        let viewWillAppear: Driver<Void>
        let viewWillLayoutSubviews: Driver<Void>
        let myPageList: Driver<[SectionType<MyPageSection>]>
        let selectedIndexPath: Driver<IndexPath>
        let embedUserInfoViewController: Driver<Void>
        let embedEmptyViewController: Driver<CustomEmptyViewStyle>
        let toastMessage: Driver<String>
        let isFetching: Driver<Bool>
        let activityIndicator: Driver<Bool>
        let showErrorPopup: Driver<Void>
    }
}

// MARK: - ViewModel Build
extension MyPageViewModel {
    func build(input: Input) -> Output {
        let (firebaseManager, updater, keychainManager) = (self.firebaseManager, self.updater, self.keychainManager)

        // 화면이 보여지기 전에
        let viewWillAppear = input.viewWillAppear
            .do(onNext: { _ in
                // analytics screen event
                firebaseManager.screenName("마이페이지")
            })

        // 최초 진입 시
        let initialLoad = input.viewWillAppear
            .asObservable()
            .take(1)
            .asDriver(onErrorDriveWith: .empty())

        // 세션 갱신 시
        let refreshSession = updater.refreshSession
            .asDriver(onErrorDriveWith: .empty())

        // pull to refresh 액션 시
        let refreshControlDidRefresh = input.refreshControlDidRefresh

        // 새로고침 필요 시
        let loadRetry = loadRetryTrigger
            .asDriver(onErrorDriveWith: .empty())

        // 최초 진입 시, 세션 갱신 시, pull to refresh 액션 시
        let loadPage = Driver.merge(initialLoad, refreshSession, refreshControlDidRefresh)

        // 최초 진입 시, 세션 갱신 시, pull to refresh 액션 시, 새로고침 필요 시
        // 유저 정보 호출
        let userMeAction = Driver.merge(loadPage, loadRetry)
            .map { UserAPI.me }
            .map(PictionSDK.rx.requestAPI)
            .flatMap(Action.makeDriver)

        // 유저 정보 호출 성공 시
        let userMeSuccess = userMeAction.elements
            // 프로젝트 섹션
            .map { _ -> [SectionType<MyPageSection>] in
                let projectItems: [MyPageSection] = [
                    MyPageSection.header(title: LocalizationKey.str_project.localized()),
                    MyPageSection.pushType(title: LocalizationKey.menu_my_project.localized()),
                    MyPageSection.underline
                ]

                // 지갑 관리 섹션
                let walletItems: [MyPageSection] = [
                    MyPageSection.header(title: LocalizationKey.str_piction_address_management.localized()),
                    MyPageSection.pushType(title: LocalizationKey.str_transactions.localized()),
                    MyPageSection.pushType(title: LocalizationKey.str_deposit.localized()),
                    MyPageSection.underline
                ]

                // 보안 섹션
                var securityItems: [MyPageSection] = [
                    MyPageSection.header(title: LocalizationKey.str_security.localized()),
                    keychainManager.get(key: .pincode).isEmpty ? MyPageSection.presentType(title: LocalizationKey.str_create_pin.localized(), align: .left) : MyPageSection.presentType(title: LocalizationKey.str_change_pin.localized(), align: .left),
                    MyPageSection.underline
                ]

                // pincode가 저장되어 있으면 가능한 생채 인식 확인
                if !keychainManager.get(key: .pincode).isEmpty {
                    let authContext = LAContext()
                    if authContext.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil) {
                        var description = ""
                        switch authContext.biometryType {
                        case .faceID:
                            description = "Face ID"
                        case .touchID:
                            description = "Touch ID"
                        case .none:
                            break
                        @unknown default:
                            break
                        }

                        // 생채 인식이 가능하다면 생채인식 row 추가
                        if description != "" {
                            let element = MyPageSection.switchType(title: description, key: "isEnabledAuthBio")
                            securityItems.insert(element, at: 2)
                        }
                    }
                }

                // 회원 정보 섹션
                let myInfoItems: [MyPageSection] = [
                    MyPageSection.header(title: LocalizationKey.str_user_profile.localized()),
                    MyPageSection.presentType(title: LocalizationKey.str_change_basic_info.localized(), align: .left),
                    MyPageSection.presentType(title: LocalizationKey.str_change_pw.localized(), align: .left),
                    MyPageSection.underline
                ]

                // 고객센터 섹션
                let supportItems: [MyPageSection] = [
                    MyPageSection.header(title: LocalizationKey.str_service_center.localized()),
                    MyPageSection.presentType(title: LocalizationKey.str_terms.localized(), align: .left),
                    MyPageSection.presentType(title: LocalizationKey.str_privacy.localized(), align: .left),
                    MyPageSection.underline
                ]

                // 로그아웃 섹션
                let logoutItems: [MyPageSection] = [
                    MyPageSection.presentType(title: LocalizationKey.str_sign_out.localized(), align: .center),
                    MyPageSection.underline
                ]

                let section: [SectionType<MyPageSection>] = [
                    SectionType<MyPageSection>.Section(title: "project", items: projectItems),
                    SectionType<MyPageSection>.Section(title: "wallet", items: walletItems),
                    SectionType<MyPageSection>.Section(title: "security", items: securityItems),
                    SectionType<MyPageSection>.Section(title: "myInfo", items: myInfoItems),
                    SectionType<MyPageSection>.Section(title: "support", items: supportItems),
                    SectionType<MyPageSection>.Section(title: "logout", items: logoutItems)
                ]
                return section
            }

        // 유저 정보 호출 에러 시
        let userMeError = userMeAction.error
            .flatMap { response -> Driver<Void> in
                let errorMsg = response as? ErrorType
                switch errorMsg {
                case .unauthorized:
                    return Driver.empty()
                default:
                    return Driver.just(())
                }
            }

        // 유저 정보 없을 때
        let userMeEmpty = userMeAction.error
            .map { _ in [SectionType<MyPageSection>]() }

        // 마이페이지 리스트
        let myPageList = Driver.merge(userMeSuccess, userMeEmpty)

        // 에러 팝업 출력
        let showErrorPopup = userMeError

        // 유저 정보 호출 에러 시 unauthorized일 때 emptyView 출력
        let embedEmptyViewController = userMeAction.error
            .flatMap { response -> Driver<CustomEmptyViewStyle> in
                let errorMsg = response as? ErrorType
                switch errorMsg {
                case .unauthorized:
                    return Driver.just(.defaultLogin)
                default:
                    return Driver.empty()
                }
            }

        // 로그아웃 버튼 누르면
        // 로그아웃 호출
        let signOutAction = input.logout
            .map { SessionAPI.delete }
            .map(PictionSDK.rx.requestAPI)
            .flatMap(Action.makeDriver)

        // 로그아웃 성공 시
        let signOutSuccess = signOutAction.elements
            .do(onNext: { _ in
                keychainManager.set(key: .accessToken, value: "")
                PictionManager.setToken("")
                updater.refreshSession.onNext(())
            })
            .map { _ in LocalizationKey.str_sign_out_success.localized() }

        // 로그아웃 에러 시
        let signOutError = signOutAction.error
            .map { $0 as? ErrorType }
            .map { $0?.message }
            .flatMap(Driver.from)

        // 유저 정보 호출 성공 시 UserInfoViewController embed
        let embedUserInfoViewController = userMeAction.elements
            .map { _ in Void() }

        // 토스트 메시지
        let toastMessage = Driver.merge(
            signOutSuccess,
            signOutError)

        // pull to refresh 로딩 및 해제
        let refreshAction = input.refreshControlDidRefresh
            .withLatestFrom(myPageList)
            .map { _ in Void() }
            .map(Driver.from)
            .flatMap(Action.makeDriver)

        // 로딩 뷰
        let activityIndicator = userMeAction.isExecuting

        return Output(
            viewWillAppear: viewWillAppear,
            viewWillLayoutSubviews: input.viewWillLayoutSubviews,
            myPageList: myPageList,
            selectedIndexPath: input.selectedIndexPath,
            embedUserInfoViewController: embedUserInfoViewController,
            embedEmptyViewController: embedEmptyViewController,
            toastMessage: toastMessage,
            isFetching: refreshAction.isExecuting,
            activityIndicator: activityIndicator,
            showErrorPopup: showErrorPopup
        )
    }
}
