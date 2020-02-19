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
        FirebaseManagerProtocol,
        UpdaterProtocol,
        KeyboardManagerProtocol
    )

    private let firebaseManager: FirebaseManagerProtocol
    private let updater: UpdaterProtocol
    private let keyboardManager: KeyboardManagerProtocol

    init(dependency: Dependency) {
        (firebaseManager, updater, keyboardManager) = dependency
    }

    private let imageId = PublishSubject<String?>()
    private let email = PublishSubject<String>()
    private let username = PublishSubject<String>()
    private let changeInfo = PublishSubject<Bool>()
    private let password = PublishSubject<String?>()

    struct Input {
        let viewWillAppear: Driver<Void>
        let viewWillDisappear: Driver<Void>
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
        let viewWillDisappear: Driver<Void>
        let userInfo: Driver<UserViewResponse>
        let pictureBtnAction: Driver<Void>
        let changePicture: Driver<UIImage?>
        let enableSaveButton: Driver<Bool>
        let openPasswordPopup: Driver<Void>
        let openWarningPopup: Driver<Void>
        let showErrorLabel: Driver<String>
        let hideErrorLabel: Driver<Void>
        let keyboardWillChangeFrame: Driver<ChangedKeyboardFrame>
        let activityIndicator: Driver<Bool>
        let dismissViewController: Driver<Void>
        let toastMessage: Driver<String>
    }

    func build(input: Input) -> Output {
        let (firebaseManager, updater, keyboardManager) = (self.firebaseManager, self.updater, self.keyboardManager)

        let viewWillAppear = input.viewWillAppear
            .do(onNext: { _ in
                firebaseManager.screenName("마이페이지_기본정보변경")
                keyboardManager.beginMonitoring()
            })

        let viewWillDisappear = input.viewWillDisappear
            .do(onNext: { _ in
                keyboardManager.stopMonitoring()
            })

        let initialLoad = input.viewWillAppear.asObservable().take(1).asDriver(onErrorDriveWith: .empty())

        let userInfoAction = initialLoad
            .map { UserAPI.me }
            .map(PictionSDK.rx.requestAPI)
            .flatMap(Action.makeDriver)

        let userInfoSuccess = userInfoAction.elements
            .map { try? $0.map(to: UserModel.self) }
            .flatMap(Driver.from)
            .do(onNext: { [weak self] userInfo in
                self?.imageId.onNext("")
                self?.email.onNext(userInfo.email ?? "")
                self?.username.onNext(userInfo.username ?? "")
                self?.changeInfo.onNext(false)
            })

        let pictureBtnAction = input.pictureImageBtnDidTap

        let uploadPictureAction = input.pictureImageDidPick
            .filter { $0 != nil }
            .map { $0! }
            .map { UserAPI.uploadPicture(image: $0) }
            .map(PictionSDK.rx.requestAPI)
            .flatMap(Action.makeDriver)

        let uploadPictureError = uploadPictureAction.error
            .map { $0 as? ErrorType }
            .map { $0?.message }
            .flatMap(Driver.from)

        let uploadPictureSuccess = uploadPictureAction.elements
            .map { try? $0.map(to: StorageAttachmentModel.self) }
            .map { $0?.id }
            .flatMap(Driver<String?>.from)
            .do(onNext: { [weak self] imageId in
                self?.imageId.onNext(imageId)
                self?.changeInfo.onNext(true)
            })

        let deletePicture = input.pictureImageDidPick
            .filter { $0 == nil }
            .map { _ in String?(nil) }
            .do(onNext: { [weak self] _ in
                self?.imageId.onNext(nil)
                self?.changeInfo.onNext(true)
            })

        let changedEmail = Driver.combineLatest(input.emailTextFieldDidInput, email.asDriver(onErrorDriveWith: .empty()))
            .do(onNext: { [weak self] inputEmail, email in
                if inputEmail != "" && inputEmail != email {
                    self?.changeInfo.onNext(true)
                } else {
                    self?.changeInfo.onNext(false)
                }
            })
            .map { $0 == "" ? $1 : $0 }

        let changedUsername = Driver.combineLatest(input.userNameTextFieldDidInput, username.asDriver(onErrorDriveWith: .empty()))
            .do(onNext: { [weak self] inputUsername, username in
                if inputUsername != "" && inputUsername != username {
                    self?.changeInfo.onNext(true)
                } else {
                    self?.changeInfo.onNext(false)
                }
            })
            .map { $0 == "" ? $1 : $0 }

        let changePicture = Driver.merge(uploadPictureSuccess, deletePicture)
            .withLatestFrom(input.pictureImageDidPick)

        let changeUserInfo = Driver.combineLatest(changedEmail, changedUsername, imageId.asDriver(onErrorDriveWith: .empty())) { (email: $0, username: $1, imageId: $2) }

        let enableSaveButton = changeInfo.asDriver(onErrorDriveWith: .empty())

        let openPasswordPopup = input.saveBtnDidTap

        let saveButtonAction = input.password
            .withLatestFrom(changeUserInfo) { (password: $0, userInfo: $1) }
            .filter { $0.password != nil }
            .map { UserAPI.update(email: $1.email, username: $1.username, password: $0 ?? "", picture: $1.imageId) }
            .map(PictionSDK.rx.requestAPI)
            .flatMap(Action.makeDriver)

        let changeUserInfoError = saveButtonAction.error
            .flatMap { response -> Driver<String> in
                let errorType = response as? ErrorType
                switch errorType {
                case .badRequest(let error) where error.field == "email":
                    return Driver.empty()
                default:
                    return Driver.just(errorType?.message ?? "")
                }
            }

        let changeUserInfoSuccess = saveButtonAction.elements
            .map { _ in Void() }
            .flatMap(Driver.from)
            .do(onNext: { _ in
                updater.refreshSession.onNext(())
            })

        let showErrorLabel = saveButtonAction.error
            .flatMap { response -> Driver<String> in
                let errorType = response as? ErrorType
                switch errorType {
                case .badRequest(let error) where error.field == "email":
                    return Driver.just(errorType?.message ?? "")
                default:
                    return Driver.empty()
                }
            }

        let hideErrorLabel = input.emailTextFieldDidInput
            .map { _ in Void() }

        let openWarningPopup = input.cancelBtnDidTap
            .withLatestFrom(changeInfo.asDriver(onErrorDriveWith: .empty()))
            .filter { $0 }
            .map { _ in Void() }
            .flatMap(Driver.from)

        let dismissWithCancel = input.cancelBtnDidTap
            .withLatestFrom(changeInfo.asDriver(onErrorDriveWith: .empty()))
            .filter { !$0 }
            .map { _ in Void() }
            .flatMap(Driver.from)

        let dismissViewController = Driver.merge(dismissWithCancel, changeUserInfoSuccess)

        let keyboardWillChangeFrame = keyboardManager.keyboardWillChangeFrame.asDriver(onErrorDriveWith: .empty())

        let activityIndicator = Driver.merge(
            userInfoAction.isExecuting,
            uploadPictureAction.isExecuting,
            saveButtonAction.isExecuting)

        let toastMessage = Driver.merge(uploadPictureError, changeUserInfoError)

        return Output(
            viewWillAppear: viewWillAppear,
            viewWillDisappear: viewWillDisappear,
            userInfo: userInfoSuccess,
            pictureBtnAction: pictureBtnAction,
            changePicture: changePicture,
            enableSaveButton: enableSaveButton,
            openPasswordPopup: openPasswordPopup,
            openWarningPopup: openWarningPopup,
            showErrorLabel: showErrorLabel,
            hideErrorLabel: hideErrorLabel,
            keyboardWillChangeFrame: keyboardWillChangeFrame,
            activityIndicator: activityIndicator,
            dismissViewController: dismissViewController,
            toastMessage: toastMessage
        )
    }
}
