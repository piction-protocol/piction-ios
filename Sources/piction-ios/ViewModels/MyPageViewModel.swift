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

enum MyPageSection {
    case header(title: String)
    case pushType(title: String)
    case switchType(title: String, key: String)
    case presentType(title: String, align: NSTextAlignment)
    case underline
}

final class MyPageViewModel: InjectableViewModel {

    typealias Dependency = (
        UpdaterProtocol,
        KeychainManagerProtocol
    )

    private let updater: UpdaterProtocol
    private let keychainManager: KeychainManagerProtocol

    var loadRetryTrigger = PublishSubject<Void>()

    init(dependency: Dependency) {
        (updater, keychainManager) = dependency
    }

    struct Input {
        let viewWillAppear: Driver<Void>
        let viewWillDisappear: Driver<Void>
        let selectedIndexPath: Driver<IndexPath>
        let logout: Driver<Void>
        let refreshControlDidRefresh: Driver<Void>
    }

    struct Output {
        let viewWillAppear: Driver<Void>
        let viewWillDisappear: Driver<Void>
        let myPageList: Driver<[SectionType<MyPageSection>]>
        let selectedIndexPath: Driver<IndexPath>
        let embedUserInfoViewController: Driver<Void>
        let embedEmptyViewController: Driver<CustomEmptyViewStyle>
        let showToast: Driver<String>
        let isFetching: Driver<Bool>
        let activityIndicator: Driver<Bool>
        let showErrorPopup: Driver<Void>
    }

    func build(input: Input) -> Output {
        let (updater, keychainManager) = (self.updater, self.keychainManager)

        let initialLoad = input.viewWillAppear.asObservable().take(1).asDriver(onErrorDriveWith: .empty())

        let refreshSession = updater.refreshSession.asDriver(onErrorDriveWith: .empty())

        let refreshControlDidRefresh = input.refreshControlDidRefresh

        let loadRetry = loadRetryTrigger.asDriver(onErrorDriveWith: .empty())

        let loadPage = Driver.merge(initialLoad, refreshSession, refreshControlDidRefresh)

        let userMeAction = Driver.merge(loadPage, loadRetry)
            .map { UserAPI.me }
            .map(PictionSDK.rx.requestAPI)
            .flatMap(Action.makeDriver)

        let userMeSuccess = userMeAction.elements
            .map { _ -> [SectionType<MyPageSection>] in
                let projectItems: [MyPageSection] = [
                    MyPageSection.header(title: LocalizedStrings.str_project.localized()),
                    MyPageSection.pushType(title: LocalizedStrings.menu_my_project.localized()),
                    MyPageSection.underline
                ]

                let walletItems: [MyPageSection] = [
                    MyPageSection.header(title: LocalizedStrings.str_piction_address_management.localized()),
                    MyPageSection.pushType(title: LocalizedStrings.str_transactions.localized()),
                    MyPageSection.pushType(title: LocalizedStrings.str_deposit.localized()),
                    MyPageSection.underline
                ]

                var securityItems: [MyPageSection] = [
                    MyPageSection.header(title: LocalizedStrings.str_security.localized()),
                    keychainManager.get(key: .pincode).isEmpty ? MyPageSection.presentType(title: LocalizedStrings.str_create_pin.localized(), align: .left) : MyPageSection.presentType(title: LocalizedStrings.str_change_pin.localized(), align: .left),
                    MyPageSection.underline
                ]

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
                        }

                        if description != "" {
                            let element = MyPageSection.switchType(title: description, key: "isEnabledAuthBio")
                            securityItems.insert(element, at: 2)
                        }
                    }
                }

                let myInfoItems: [MyPageSection] = [
                    MyPageSection.header(title: LocalizedStrings.str_user_profile.localized()),
                    MyPageSection.presentType(title: LocalizedStrings.str_change_basic_info.localized(), align: .left),
                    MyPageSection.presentType(title: LocalizedStrings.str_change_pw.localized(), align: .left),
                    MyPageSection.underline
                ]

                let supportItems: [MyPageSection] = [
                    MyPageSection.header(title: LocalizedStrings.str_service_center.localized()),
                    MyPageSection.presentType(title: LocalizedStrings.str_terms.localized(), align: .left),
                    MyPageSection.presentType(title: LocalizedStrings.str_privacy.localized(), align: .left),
                    MyPageSection.underline
                ]

                let logoutItems: [MyPageSection] = [
                    MyPageSection.presentType(title: LocalizedStrings.str_sign_out.localized(), align: .center),
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

        let userMeEmpty = userMeAction.error
            .map { _ in [SectionType<MyPageSection>]() }

        let myPageList = Driver.merge(userMeSuccess, userMeEmpty)
        let showErrorPopup = userMeError

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

        let signOutAction = input.logout
            .map { SessionAPI.delete }
            .map(PictionSDK.rx.requestAPI)
            .flatMap(Action.makeDriver)

        let signOutError = signOutAction.error
            .map { $0 as? ErrorType }
            .map { $0?.message }
            .flatMap(Driver.from)

        let signOutSuccess = signOutAction.elements
            .do(onNext: { _ in
                keychainManager.set(key: .accessToken, value: "")
                PictionManager.setToken("")
                updater.refreshSession.onNext(())
            })
            .map { _ in LocalizedStrings.str_sign_out_success.localized() }

        let embedUserInfoViewController = userMeAction.elements
            .map { _ in Void() }

        let showToast = Driver.merge(signOutSuccess, signOutError)

        let refreshAction = input.refreshControlDidRefresh
            .withLatestFrom(myPageList)
            .map { _ in Void() }
            .map(Driver.from)
            .flatMap(Action.makeDriver)

        let activityIndicator = userMeAction.isExecuting

        return Output(
            viewWillAppear: input.viewWillAppear,
            viewWillDisappear: input.viewWillDisappear,
            myPageList: myPageList,
            selectedIndexPath: input.selectedIndexPath,
            embedUserInfoViewController: embedUserInfoViewController,
            embedEmptyViewController: embedEmptyViewController,
            showToast: showToast,
            isFetching: refreshAction.isExecuting,
            activityIndicator: activityIndicator,
            showErrorPopup: showErrorPopup
        )
    }
}
