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
        UpdaterProtocol
    )

    private let updater: UpdaterProtocol

    init(dependency: Dependency) {
        (updater) = dependency
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
    }

    func build(input: Input) -> Output {

        let viewWillAppear = input.viewWillAppear.asObservable().take(1).asDriver(onErrorDriveWith: .empty())

        let viewWillDisappear = input.viewWillDisappear

        let refreshSession = updater.refreshSession.asDriver(onErrorDriveWith: .empty())

        let refreshControlDidRefresh = input.refreshControlDidRefresh

        let userMeAction = Driver.merge(viewWillAppear, refreshSession, refreshControlDidRefresh)
            .flatMap { _ -> Driver<Action<ResponseData>> in
                let response = PictionSDK.rx.requestAPI(UsersAPI.me)
                return Action.makeDriver(response)
            }

        let userMeSuccess = userMeAction.elements
            .flatMap { _ -> Driver<[SectionType<MyPageSection>]> in
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
                    KeychainManager.get(key: "pincode").isEmpty ? MyPageSection.presentType(title: LocalizedStrings.str_create_pin.localized(), align: .left) : MyPageSection.presentType(title: LocalizedStrings.str_change_pin.localized(), align: .left),
                    MyPageSection.underline
                ]

                if !KeychainManager.get(key: "pincode").isEmpty {
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
                return Driver.just(section)
            }

        let userMeError = userMeAction.error
            .flatMap { _ -> Driver<[SectionType<MyPageSection>]> in
                return Driver.just([])
            }

        let myPageList = Driver.merge(userMeSuccess, userMeError)

        let embedEmptyViewController = userMeAction.error
            .flatMap { response -> Driver<CustomEmptyViewStyle> in
                guard let errorMsg = response as? ErrorType else {
                    return Driver.empty()
                }
                switch errorMsg {
                case .unauthorized:
                    return Driver.just(.defaultLogin)
                default:
                    return Driver.empty()
                }
        }

        let signOutAction = input.logout
            .flatMap { _ -> Driver<Action<ResponseData>> in
                let response = PictionSDK.rx.requestAPI(SessionsAPI.delete)
                return Action.makeDriver(response)
            }

        let signOutError = signOutAction.error
            .flatMap { response -> Driver<String> in
                let errorMsg = response as? ErrorType
                return Driver.just(errorMsg?.message ?? "")
            }

        let signOutSuccess = signOutAction.elements
            .flatMap { [weak self] response -> Driver<String> in
                guard let accessToken = try? response.map(to: AuthenticationViewResponse.self) else {
                    return Driver.empty()
                }
                KeychainManager.set(key: "AccessToken", value: "")
                PictionManager.setToken("")
                self?.updater.refreshSession.onNext(())
                return Driver.just(LocalizedStrings.str_sign_out_success.localized())
            }

        let embedUserInfoViewController = userMeAction.elements
            .flatMap { _ in Driver.just(()) }

        let showToast = Driver.merge(signOutSuccess, signOutError)

        let refreshAction = input.refreshControlDidRefresh
        .withLatestFrom(myPageList)
        .flatMap { _ -> Driver<Action<Void>> in
            return Action.makeDriver(Driver.just(()))
        }

        return Output(
            viewWillAppear: input.viewWillAppear,
            viewWillDisappear: viewWillDisappear,
            myPageList: myPageList,
            selectedIndexPath: input.selectedIndexPath,
            embedUserInfoViewController: embedUserInfoViewController,
            embedEmptyViewController: embedEmptyViewController,
            showToast: showToast,
            isFetching: refreshAction.isExecuting
        )
    }
}
