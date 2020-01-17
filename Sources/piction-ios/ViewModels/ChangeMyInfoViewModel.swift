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
        let keyboardWillChangeFrame: Driver<ChangedKeyboardFrame>
        let activityIndicator: Driver<Bool>
        let dismissViewController: Driver<Void>
        let showToast: Driver<String>
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
            .do(onNext: { [weak self] _ in
                self?.imageId.onNext("")
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

        let changePicture = Driver.merge(uploadPictureSuccess, deletePicture)
            .withLatestFrom(input.pictureImageDidPick)

        let userNameChanged = Driver.combineLatest(input.userNameTextFieldDidInput, userInfoSuccess) { (inputUsername: $0, username: $1.username) }
            .filter { $0.inputUsername != "" }
            .filter { $0.inputUsername != $0.username }
            .map { $0.inputUsername }
            .do(onNext: { [weak self] _ in
                self?.changeInfo.onNext(true)
            })

        let changeUserInfo = Driver.combineLatest(userNameChanged, imageId.asDriver(onErrorDriveWith: .empty())) { (username: $0, imageId: $1) }

        let enableSaveButton = changeInfo.asDriver(onErrorDriveWith: .empty())
            .filter { $0 }

        let password = input.password

        let openPasswordPopup = input.saveBtnDidTap

        let saveButtonAction = Driver.combineLatest(password, changeUserInfo) { (password: $0, userInfo: $1) }
            .filter { $0.password != nil }
            .map { UserAPI.update(username: $1.username, password: $0 ?? "", picture: $1.imageId) }
            .map(PictionSDK.rx.requestAPI)
            .flatMap(Action.makeDriver)

        let changeUserInfoError = saveButtonAction.error
            .map { $0 as? ErrorType }
            .map { $0?.message }
            .flatMap(Driver.from)

        let changeUserInfoSuccess = saveButtonAction.elements
            .map { _ in Void() }
            .flatMap(Driver.from)
            .do(onNext: { _ in
                updater.refreshSession.onNext(())
            })

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

        let showToast = Driver.merge(changeUserInfoError, uploadPictureError)

        return Output(
            viewWillAppear: viewWillAppear,
            viewWillDisappear: viewWillDisappear,
            userInfo: userInfoSuccess,
            pictureBtnAction: pictureBtnAction,
            changePicture: changePicture,
            enableSaveButton: enableSaveButton,
            openPasswordPopup: openPasswordPopup,
            openWarningPopup: openWarningPopup,
            keyboardWillChangeFrame: keyboardWillChangeFrame,
            activityIndicator: activityIndicator,
            dismissViewController: dismissViewController,
            showToast: showToast
        )
    }
}
