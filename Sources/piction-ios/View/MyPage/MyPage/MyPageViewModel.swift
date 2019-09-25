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
    }

    struct Output {
        let viewWillAppear: Driver<Void>
        let viewWillDisappear: Driver<Void>
        let myPageList: Driver<[MyPageBySection]>
        let selectedIndexPath: Driver<IndexPath>
        let embedUserInfoViewController: Driver<Void>
        let embedEmptyViewController: Driver<CustomEmptyViewStyle>
        let showToast: Driver<String>
    }

    func build(input: Input) -> Output {

        let viewWillAppear = input.viewWillAppear.asObservable().take(1).asDriver(onErrorDriveWith: .empty())

        let viewWillDisappear = input.viewWillDisappear

        let refreshSession = updater.refreshSession.asDriver(onErrorDriveWith: .empty())

        let userMeAction = Driver.merge(viewWillAppear, refreshSession)
            .flatMap { _ -> Driver<Action<ResponseData>> in
                let response = PictionSDK.rx.requestAPI(UsersAPI.me)
                return Action.makeDriver(response)
            }

        let userMeSuccess = userMeAction.elements
            .flatMap { _ -> Driver<[MyPageBySection]> in
                let projectItems: [MyPageItemType] = [
                    MyPageItemType.header(title: "프로젝트"),
                    MyPageItemType.pushType(title: "나의 프로젝트"),
                    MyPageItemType.underline
                ]

                let walletItems: [MyPageItemType] = [
                    MyPageItemType.header(title: "픽션 지갑관리"),
                    MyPageItemType.pushType(title: "거래 내역"),
                    MyPageItemType.pushType(title: "픽션 지갑으로 입금"),
                    MyPageItemType.underline
                ]

                var securityItems: [MyPageItemType] = [
                    MyPageItemType.header(title: "보안"),
                    UserDefaults.standard.string(forKey: "pincode") == nil ? MyPageItemType.presentType(title: "PIN 번호 등록", align: .left) : MyPageItemType.presentType(title: "PIN 번호 변경", align: .left),
                    MyPageItemType.underline
                ]

                if UserDefaults.standard.string(forKey: "pincode") != nil {
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
                    MyPageItemType.header(title: "회원 정보"),
                    MyPageItemType.presentType(title: "기본정보 변경", align: .left),
                    MyPageItemType.presentType(title: "비밀번호 변경", align: .left),
                    MyPageItemType.underline
                ]

                let supportItems: [MyPageItemType] = [
                    MyPageItemType.header(title: "고객센터"),
                    MyPageItemType.presentType(title: "서비스 이용약관", align: .left),
                    MyPageItemType.presentType(title: "개인정보 처리방침", align: .left),
                    MyPageItemType.underline
                ]

                let logoutItems: [MyPageItemType] = [
                    MyPageItemType.presentType(title: "로그아웃", align: .center),
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
                self?.updater.refreshSession.onNext(())
                print(accessToken)
                return Driver.just("로그아웃 되었습니다.")
            }

        let embedUserInfoViewController = userMeAction.elements
            .flatMap { _ in Driver.just(()) }

        let showToast = Driver.merge(signOutSuccess, signOutError)

        return Output(
            viewWillAppear: input.viewWillAppear,
            viewWillDisappear: viewWillDisappear,
            myPageList: myPageList,
            selectedIndexPath: input.selectedIndexPath,
            embedUserInfoViewController: embedUserInfoViewController,
            embedEmptyViewController: embedEmptyViewController,
            showToast: showToast
        )
    }
}
