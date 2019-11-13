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
        let myPageList: Driver<[MyPageBySection]>
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
            .flatMap { _ -> Driver<[MyPageBySection]> in
                let projectItems: [MyPageItemType] = [
                    MyPageItemType.header(title: LocalizedStrings.str_project.localized()),
                    MyPageItemType.pushType(title: LocalizedStrings.menu_my_project.localized()),
                    MyPageItemType.underline
                ]

                let walletItems: [MyPageItemType] = [
                    MyPageItemType.header(title: LocalizedStrings.str_piction_address_management.localized()),
                    MyPageItemType.pushType(title: LocalizedStrings.str_transactions.localized()),
                    MyPageItemType.pushType(title: LocalizedStrings.str_deposit.localized()),
                    MyPageItemType.underline
                ]

                var securityItems: [MyPageItemType] = [
                    MyPageItemType.header(title: LocalizedStrings.str_security.localized()),
                    KeychainManager.get(key: "pincode").isEmpty ? MyPageItemType.presentType(title: LocalizedStrings.str_create_pin.localized(), align: .left) : MyPageItemType.presentType(title: LocalizedStrings.str_change_pin.localized(), align: .left),
                    MyPageItemType.underline
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
                            let element = MyPageItemType.switchType(title: description, key: "isEnabledAuthBio")
                            securityItems.insert(element, at: 2)
                        }
                    }
                }

                let myInfoItems: [MyPageItemType] = [
                    MyPageItemType.header(title: LocalizedStrings.str_user_profile.localized()),
                    MyPageItemType.presentType(title: LocalizedStrings.str_change_basic_info.localized(), align: .left),
                    MyPageItemType.presentType(title: LocalizedStrings.str_change_pw.localized(), align: .left),
                    MyPageItemType.underline
                ]

                let supportItems: [MyPageItemType] = [
                    MyPageItemType.header(title: LocalizedStrings.str_service_center.localized()),
                    MyPageItemType.presentType(title: LocalizedStrings.str_terms.localized(), align: .left),
                    MyPageItemType.presentType(title: LocalizedStrings.str_privacy.localized(), align: .left),
                    MyPageItemType.underline
                ]

                let logoutItems: [MyPageItemType] = [
                    MyPageItemType.presentType(title: LocalizedStrings.str_sign_out.localized(), align: .center),
                    MyPageItemType.underline
                ]

                let section: [MyPageBySection] = [
                    MyPageBySection.Section(title: "project", items: projectItems),
                    MyPageBySection.Section(title: "wallet", items: walletItems),
                    MyPageBySection.Section(title: "security", items: securityItems),
                    MyPageBySection.Section(title: "myInfo", items: myInfoItems),
                    MyPageBySection.Section(title: "support", items: supportItems),
                    MyPageBySection.Section(title: "logout", items: logoutItems)
                ]
                return Driver.just(section)
            }

        let userMeError = userMeAction.error
            .flatMap { _ -> Driver<[MyPageBySection]> in
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
