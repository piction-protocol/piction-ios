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

// MARK: - ViewModel
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
}

// MARK: - Input & Output
extension ChangeMyInfoViewModel {
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
}

// MARK: - ViewModel Build
extension ChangeMyInfoViewModel {
    func build(input: Input) -> Output {
        let (firebaseManager, updater, keyboardManager) = (self.firebaseManager, self.updater, self.keyboardManager)

        // 화면이 보여지기 전에
        let viewWillAppear = input.viewWillAppear
            .do(onNext: { _ in
                // analytics screen event
                firebaseManager.screenName("마이페이지_기본정보변경")
                // 키보드가 올라오는지 모니터링
                keyboardManager.beginMonitoring()
            })

        let viewWillDisappear = input.viewWillDisappear
            .do(onNext: { _ in
                // 키보드 모니터링 중단
                keyboardManager.stopMonitoring()
            })

        // 최초 진입 시
        let initialLoad = input.viewWillAppear
            .asObservable()
            .take(1)
            .asDriver(onErrorDriveWith: .empty())

        // 최초 진입 시
        // 유저 정보 호출
        let userInfoAction = initialLoad
            .map { UserAPI.me }
            .map(PictionSDK.rx.requestAPI)
            .flatMap(Action.makeDriver)

        // 유저 정보 호출 성공 시
        let userInfoSuccess = userInfoAction.elements
            .map { try? $0.map(to: UserModel.self) }
            .flatMap(Driver.from)
            .do(onNext: { [weak self] userInfo in
                // 유저 정보 설정
                self?.imageId.onNext("")
                self?.email.onNext(userInfo.email ?? "")
                self?.username.onNext(userInfo.username ?? "")
                self?.changeInfo.onNext(false)
            })

        // 프로필 이미지 선택 시
        let pictureBtnAction = input.pictureImageBtnDidTap

        // image picker에서 이미지 선택 시
        // 이미지 업로드 호출
        let uploadPictureAction = input.pictureImageDidPick
            .filter { $0 != nil }
            .map { $0! }
            .map { UserAPI.uploadPicture(image: $0) }
            .map(PictionSDK.rx.requestAPI)
            .flatMap(Action.makeDriver)

        let uploadPictureSuccess = uploadPictureAction.elements
            .map { try? $0.map(to: StorageAttachmentModel.self) }
            .map { $0?.id }
            .flatMap(Driver<String?>.from)
            .do(onNext: { [weak self] imageId in
                self?.imageId.onNext(imageId)
                self?.changeInfo.onNext(true)
            })

        // 이미지 업로드 호출 에러 시
        let uploadPictureError = uploadPictureAction.error
            .map { $0 as? ErrorType }
            .map { $0?.message }
            .flatMap(Driver.from)

        // 이미지 삭제 시
        let deletePicture = input.pictureImageDidPick
            .filter { $0 == nil }
            .map { _ in String?(nil) }
            .do(onNext: { [weak self] _ in
                self?.imageId.onNext(nil)
                self?.changeInfo.onNext(true)
            })

        // 변경된 프로필 이미지
        let changePicture = Driver.merge(uploadPictureSuccess, deletePicture)
            .withLatestFrom(input.pictureImageDidPick)

        // 이메일 입력 시
        let changedEmail = Driver.combineLatest(input.emailTextFieldDidInput, email.asDriver(onErrorDriveWith: .empty()))
            .do(onNext: { [weak self] inputEmail, email in
                if inputEmail != "" && inputEmail != email {
                    self?.changeInfo.onNext(true)
                } else {
                    self?.changeInfo.onNext(false)
                }
            })
            .map { $0 == "" ? $1 : $0 }

        // 닉네임 입력 시
        let changedUsername = Driver.combineLatest(input.userNameTextFieldDidInput, username.asDriver(onErrorDriveWith: .empty()))
            .do(onNext: { [weak self] inputUsername, username in
                if inputUsername != "" && inputUsername != username {
                    self?.changeInfo.onNext(true)
                } else {
                    self?.changeInfo.onNext(false)
                }
            })
            .map { $0 == "" ? $1 : $0 }

        // 유저 정보가 변경되면
        let changeUserInfo = Driver.combineLatest(
            changedEmail,
            changedUsername,
            imageId.asDriver(onErrorDriveWith: .empty()))
            { (email: $0, username: $1, imageId: $2) }

        // 저장 버튼 활성화
        let enableSaveButton = changeInfo
            .asDriver(onErrorDriveWith: .empty())

        // 저장 버튼 누르면 패스워드 팝업 출력
        let openPasswordPopup = input.saveBtnDidTap

        // 패스워드 입력 후
        // 업데이트 호출
        let updateAction = input.password
            .withLatestFrom(changeUserInfo) { (password: $0, userInfo: $1) }
            .filter { $0.password != nil }
            .map { UserAPI.update(email: $1.email, username: $1.username, password: $0 ?? "", picture: $1.imageId) }
            .map(PictionSDK.rx.requestAPI)
            .flatMap(Action.makeDriver)

        // 업데이트 호출 성공 시
        let changeUserInfoSuccess = updateAction.elements
            .map { _ in Void() }
            .flatMap(Driver.from)
            .do(onNext: { _ in
                updater.refreshSession.onNext(())
            })

        // 업데이트 호출 에러 시
        // badRequest이고 email 필드가 아니면
        let changeUserInfoError = updateAction.error
            .flatMap { response -> Driver<String> in
                let errorType = response as? ErrorType
                switch errorType {
                case .badRequest(let error) where error.field == "email":
                    return Driver.empty()
                default:
                    return Driver.just(errorType?.message ?? "")
                }
            }

        // 업데이트 호출 에러 시
        // badRequest이고 email 필드이면
        let showErrorLabel = updateAction.error
            .flatMap { response -> Driver<String> in
                let errorType = response as? ErrorType
                switch errorType {
                case .badRequest(let error) where error.field == "email":
                    return Driver.just(errorType?.message ?? "")
                default:
                    return Driver.empty()
                }
            }

        // emailTextField 입력 시 error 필드 숨김
        let hideErrorLabel = input.emailTextFieldDidInput
            .map { _ in Void() }

        // 정보 변경 후 취소 버튼 누르면 경고 팝업 출력
        let openWarningPopup = input.cancelBtnDidTap
            .withLatestFrom(changeInfo.asDriver(onErrorDriveWith: .empty()))
            .filter { $0 }
            .map { _ in Void() }
            .flatMap(Driver.from)

        // 정보 변경되지 않고 취소 버튼 누르면 dismiss
        let dismissWithCancel = input.cancelBtnDidTap
            .withLatestFrom(changeInfo.asDriver(onErrorDriveWith: .empty()))
            .filter { !$0 }
            .map { _ in Void() }
            .flatMap(Driver.from)

        // 업데이트 호출 성공 시, 정보 변경 없이 취소 버튼 누를 때
        // dismiss
        let dismissViewController = Driver.merge(dismissWithCancel, changeUserInfoSuccess)

        // 키보드로 인한 frame 변경 시
        let keyboardWillChangeFrame = keyboardManager.keyboardWillChangeFrame
            .asDriver(onErrorDriveWith: .empty())

        // 로딩 뷰
        let activityIndicator = Driver.merge(
            userInfoAction.isExecuting,
            uploadPictureAction.isExecuting,
            updateAction.isExecuting)

        // 토스트 메시지
        let toastMessage = Driver.merge(
            uploadPictureError,
            changeUserInfoError)

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
