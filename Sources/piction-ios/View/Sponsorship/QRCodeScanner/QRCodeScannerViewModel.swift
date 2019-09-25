//
//  QRCodeScannerViewModel.swift
//  PictionSDK
//
//  Created by jhseo on 30/08/2019.
//  Copyright © 2019 Piction Network. All rights reserved.
//

import RxSwift
import RxCocoa
import PictionSDK

final class QRCodeScannerViewModel: ViewModel {

    init() {}

    struct Input {
        let viewWillAppear: Driver<Void>
        let viewWillDisappear: Driver<Void>
        let qrCodeDataDidLoad: Driver<String>
        let closeBtnDidTap: Driver<Void>
    }

    struct Output {
        let viewWillAppear: Driver<Void>
        let viewWillDisappear: Driver<Void>
        let openSendDonationViewController: Driver<String>
        let openErrorPopup: Driver<String>
        let dismissViewController: Driver<Void>
    }

    func build(input: Input) -> Output {

        let dismissViewController = input.closeBtnDidTap

        let findPublicAddressAction = input.qrCodeDataDidLoad
            .flatMap { qrCodeString -> Driver<Action<ResponseData>> in
                let split = qrCodeString.split(separator: ":")
//                if split[0] == "klaytn" {
                let response = PictionSDK.rx.requestAPI(UsersAPI.findPublicAddress(address: String(split[safe: 1] ?? "") ))
                    return Action.makeDriver(response)
//                }
//                return Driver.empty()
            }

        let findPublicAddressSuccess = findPublicAddressAction.elements
            .flatMap { response -> Driver<String> in
                guard let userInfo = try? response.map(to: UserModel.self) else {
                    return Driver.empty()
                }
                return Driver.just(userInfo.loginId ?? "")
            }

        let findPublicAddressError = findPublicAddressAction.error
            .flatMap { _ -> Driver<String> in
                return Driver.just("픽션 크리에이터 QR코드가 아닙니다.")
            }


        return Output(
            viewWillAppear: input.viewWillAppear,
            viewWillDisappear: input.viewWillDisappear,
            openSendDonationViewController: findPublicAddressSuccess,
            openErrorPopup: findPublicAddressError,
            dismissViewController: dismissViewController
        )
    }
}
