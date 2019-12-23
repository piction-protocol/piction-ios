//
//  ChangeMyInfoViewModel.swift
//  PictionView
//
//  Created by jhseo on 19/06/2019.
//  Copyright © 2019 Piction Network. All rights reserved.
//

import UIKit
import RxSwift
import RxCocoa
import PictionSDK

final class ChangeMyInfoViewModel: InjectableViewModel {

    typealias Dependency = (
        UpdaterProtocol
    )

    private let updater: UpdaterProtocol

    init(dependency: Dependency) {
        (updater) = dependency
    }

    private let imageId = PublishSubject<String?>()
    private let changeInfo = PublishSubject<Bool>()
    private let password = PublishSubject<String?>()

    struct Input {
        let viewWillAppear: Driver<Void>
        let emailTextFieldDidInput: Driver<String>
        let userNameTextFieldDidInput: Driver<String>
        let pictureImageBtnDidTap: Driver<Void>
        let pictureImageDidPick: Driver<UIImage?>
        let cancelBtnDidTap: Driver<Void>
        let saveBtnDidTap: Driver<Void>
        let password: Driver<String?>
    }

    struct Output {
        let viewWillAppear: Driver<Void>
        let userInfo: Driver<UserViewResponse>
        let pictureBtnAction: Driver<Void>
        let changePicture: Driver<UIImage?>
        let enableSaveButton: Driver<Bool>
        let openPasswordPopup: Driver<Void>
        let openWarningPopup: Driver<Void>
        let activityIndicator: Driver<Bool>
        let dismissViewController: Driver<Void>
        let showToast: Driver<String>
    }

    func build(input: Input) -> Output {
        let updater = self.updater

        let userInfoAction = input.viewWillAppear.asObservable().take(1).asDriver(onErrorDriveWith: .empty())
            .flatMap { _ -> Driver<Action<ResponseData>> in
                let response = PictionSDK.rx.requestAPI(UsersAPI.me)
                return Action.makeDriver(response)
            }

        let userInfoSuccess = userInfoAction.elements
            .flatMap { [weak self] response -> Driver<UserViewResponse> in
                guard
                    let `self` = self,
                    let userInfo = try? response.map(to: UserViewResponse.self)
                else { return Driver.empty() }

                self.imageId.onNext("")
                self.changeInfo.onNext(false)
                return Driver.just(userInfo)
            }

        let pictureBtnAction = input.pictureImageBtnDidTap

        let uploadPictureAction = input.pictureImageDidPick
            .filter { $0 != nil }
            .flatMap { image -> Driver<Action<ResponseData>> in
                guard let image = image else { return Driver.empty() }
                let response = PictionSDK.rx.requestAPI(UsersAPI.uploadPicture(image: image))
                return Action.makeDriver(response)
            }

        let uploadPictureError = uploadPictureAction.error
            .flatMap { response -> Driver<String> in
                guard let errorMsg = response as? ErrorType else { return Driver.empty() }
                return Driver.just(errorMsg.message)
            }

        let uploadPictureSuccess = uploadPictureAction.elements
            .flatMap { [weak self] response -> Driver<String?> in
                guard
                    let `self` = self,
                    let imageInfo = try? response.map(to: StorageAttachmentViewResponse.self),
                    let imageInfoId = imageInfo.id
                else { return Driver.empty() }

                self.imageId.onNext(imageInfoId)
                self.changeInfo.onNext(true)
                return Driver.just(imageInfoId)
            }

        let deletePicture = input.pictureImageDidPick
            .filter { $0 == nil }
            .flatMap { [weak self] _ -> Driver<String?> in
                guard let `self` = self else { return Driver.empty() }
                self.imageId.onNext(nil)
                self.changeInfo.onNext(true)
                return Driver.just(nil)
            }

        let changePicture = Driver.merge(uploadPictureSuccess, deletePicture)
            .withLatestFrom(input.pictureImageDidPick)
            .flatMap { image in Driver<UIImage?>.just(image) }

        let userNameChanged = Driver.combineLatest(input.userNameTextFieldDidInput, userInfoSuccess)
            .flatMap { [weak self] (inputUsername, userInfo) -> Driver<String> in
                guard
                    let `self` = self,
                    let userName = userInfo.username
                else { return Driver.empty() }

                if inputUsername != "" && inputUsername != userName {
                    self.changeInfo.onNext(true)
                }
                return Driver.just(inputUsername)
            }

        let changeUserInfo = Driver.combineLatest(userNameChanged, imageId.asDriver(onErrorDriveWith: .empty())) { (username: $0, imageId: $1) }

        let enableSaveButton = changeInfo.asDriver(onErrorDriveWith: .empty())
            .filter { $0 }

        let password = input.password
            .flatMap { password in Driver<String?>.just(password) }

        let openPasswordPopup = input.saveBtnDidTap

        let saveButtonAction = Driver.combineLatest(password, changeUserInfo) { (password: $0, userInfo: $1) }
            .filter { $0.password != nil }
            .flatMap { (password, changeUserInfo) -> Driver<Action<ResponseData>> in
                let response = PictionSDK.rx.requestAPI(UsersAPI.update(username: changeUserInfo.username, password: password ?? "", picture: changeUserInfo.imageId))
                return Action.makeDriver(response)
            }

        let changeUserInfoError = saveButtonAction.error
            .flatMap { response -> Driver<String> in
                guard let errorMsg = response as? ErrorType else { return Driver.empty() }
                return Driver.just(errorMsg.message)
            }

        let changeUserInfoSuccess = saveButtonAction.elements
            .flatMap { response -> Driver<Void> in
                updater.refreshSession.onNext(())
                return Driver.just(())
            }

        let openWarningPopup = input.cancelBtnDidTap
            .withLatestFrom(changeInfo.asDriver(onErrorDriveWith: .empty()))
            .filter { $0 }
            .flatMap { _ in Driver.just(()) }

        let dismissWithCancel = input.cancelBtnDidTap
            .withLatestFrom(changeInfo.asDriver(onErrorDriveWith: .empty()))
            .filter { !$0 }
            .flatMap { _ in Driver.just(()) }

        let dismissViewController = Driver.merge(dismissWithCancel, changeUserInfoSuccess)
            .flatMap { _ in Driver.just(()) }

        let activityIndicator = Driver.merge(
            userInfoAction.isExecuting,
            uploadPictureAction.isExecuting,
            saveButtonAction.isExecuting)

        let showToast = Driver.merge(changeUserInfoError, uploadPictureError)

        return Output(
            viewWillAppear: input.viewWillAppear,
            userInfo: userInfoSuccess,
            pictureBtnAction: pictureBtnAction,
            changePicture: changePicture,
            enableSaveButton: enableSaveButton,
            openPasswordPopup: openPasswordPopup,
            openWarningPopup: openWarningPopup,
            activityIndicator: activityIndicator,
            dismissViewController: dismissViewController,
            showToast: showToast
        )
    }
}
