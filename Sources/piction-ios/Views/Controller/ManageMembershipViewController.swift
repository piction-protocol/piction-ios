//
//  ManageMembershipViewController.swift
//  piction-ios
//
//  Created by jhseo on 2019/11/22.
//  Copyright © 2019 Piction Network. All rights reserved.
//

import UIKit
import RxSwift
import RxCocoa
import ViewModelBindable
import RxDataSources
import PictionSDK

// 현재 사용하지 않는 화면입니다. (에디터 기능 지원안함)

// MARK: - ManageMembershipDelegate
protocol ManageMembershipDelegate: class {
    func selectMembership(with membership: MembershipModel?)
}

// MARK: - UIViewController
final class ManageMembershipViewController: UIViewController {
    var disposeBag = DisposeBag()

    @IBOutlet weak var closeButton: UIBarButtonItem!
    @IBOutlet weak var createButton: UIBarButtonItem!
    @IBOutlet weak var tableView: UITableView!

    weak var delegate: ManageMembershipDelegate?

    private let deleteMembership = PublishSubject<(String, Int)>()

    override func viewDidLoad() {
        super.viewDidLoad()

        // present 타입의 경우 viewDidLoad에서 navigation을 설정
        self.navigationController?.configureNavigationBar(transparent: false, shadow: true)
    }
    
    deinit {
        // 메모리 해제되는지 확인
        print("[deinit] \(String(describing: type(of: self)))")
    }
}

// MARK: - ViewModelBindable
extension ManageMembershipViewController: ViewModelBindable {
    typealias ViewModel = ManageMembershipViewModel

    func bindViewModel(viewModel: ViewModel) {
        let dataSource = configureDataSource()

        tableView.rx.setDelegate(self)
            .disposed(by: disposeBag)

        let input = ManageMembershipViewModel.Input(
            viewWillAppear: rx.viewWillAppear.asDriver(), // 화면이 보여지기 전에
            selectedIndexPath: tableView.rx.itemSelected.asDriver(), // tableView의 row를 눌렀을 때
            createBtnDidTap: createButton.rx.tap.asDriver(), // 생성 버튼 눌렀을 때
            deleteMembership: deleteMembership.asDriver(onErrorDriveWith: .empty()), // 멤버십 삭제 동작 시
            closeBtnDidTap: closeButton.rx.tap.asDriver() // 닫기 버튼 눌렀을 때
        )

        let output = viewModel.build(input: input)

        // 화면이 보여지기 전에 NavigationBar 설정
        output
            .viewWillAppear
            .drive(onNext: { [weak self] in
                self?.navigationController?.configureNavigationBar(transparent: false, shadow: true)
                self?.tableView.allowsSelection = self?.delegate != nil
                self?.tableView.allowsSelectionDuringEditing = self?.delegate != nil
            })
            .disposed(by: disposeBag)

        output
            .membershipList
            .drive { $0 }
            .map { [SectionModel(model: "membership", items: $0)] }
            .bind(to: tableView.rx.items(dataSource: dataSource))
            .disposed(by: disposeBag)

        output
            .membershipList
            .drive(onNext: { [weak self] membershipList in
                let selectedMembershipId = self?.viewModel?.membershipId ?? 0
                guard let seriesIndex = membershipList.firstIndex(where: { $0.id == selectedMembershipId }) else { return }
                let indexPath = IndexPath(row: seriesIndex, section: 0)
                self?.tableView.selectRow(at: indexPath, animated: false, scrollPosition: .middle)
            })
            .disposed(by: disposeBag)

        output
            .selectedIndexPath
            .drive(onNext: { [weak self] indexPath in
                guard let delegate = self?.delegate else { return }
                let membership = dataSource[indexPath]
                delegate.selectMembership(with: membership)
            })
            .disposed(by: disposeBag)

        output
            .openCreateMembershipViewController
            .map { .createMembership(uri: $0) }
            .drive(onNext: { [weak self] in
                self?.openView(type: $0, openType: .push)
            })
            .disposed(by: disposeBag)

        // 로딩 뷰
        output
            .activityIndicator
            .loadingActivity()
            .disposed(by: disposeBag)

        // 네트워크 오류 시 에러 팝업 출력
        output
            .showErrorPopup
            .drive(onNext: { [weak self] in
                Toast.loadingActivity(false) // 로딩 뷰 로딩 중이면 로딩 해제
                self?.showPopup(
                    title: LocalizationKey.popup_title_network_error.localized(),
                    message: LocalizationKey.msg_api_internal_server_error.localized(),
                    action: [LocalizationKey.retry.localized(), LocalizationKey.cancel.localized()]) { [weak self] in
                        // 다시 로딩
                        self?.viewModel?.loadRetryTrigger.onNext(())
                    }
            })
            .disposed(by: disposeBag)

        // 화면을 닫음
        output
            .dismissViewController
            .drive(onNext: { [weak self] message in
                self?.dismiss(animated: true)
            })
            .disposed(by: disposeBag)

        // 토스트 메시지 출력
        output
            .toastMessage
            .showToast()
            .disposed(by: disposeBag)
    }
}

// MARK: - UITableViewDelegate
extension ManageMembershipViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let editAction = UIContextualAction(style: .normal, title: LocalizationKey.edit.localized(), handler: { [weak self] (action, view, completionHandler) in
            guard let uri = self?.viewModel?.uri else { return }
            if let membership: MembershipModel = try? self?.tableView.rx.model(at: indexPath) {
                self?.openView(type: .createMembership(uri: uri, membership: membership), openType: .push)
                completionHandler(true)
            }
        })
        let deleteAction = UIContextualAction(style: .destructive, title: LocalizationKey.delete.localized(), handler: { [weak self] (action, view, completionHandler) in
            guard let uri = self?.viewModel?.uri else { return }
            if let membership: MembershipModel = try? self?.tableView.rx.model(at: indexPath) {
                self?.openDeletePopup(uri: uri, membership: membership)
                completionHandler(true)
            }
        })
        let lastIndexPath = tableView.numberOfRows(inSection: 0)
        if indexPath.row == 0 || indexPath.row < lastIndexPath - 1 {
            return UISwipeActionsConfiguration(actions: [editAction])
        } else {
            return UISwipeActionsConfiguration(actions: [deleteAction, editAction])
        }
    }

    func tableView(_ tableView: UITableView, willSelectRowAt indexPath: IndexPath) -> IndexPath? {
        if let indexPathForSelectedRow = tableView.indexPathForSelectedRow,
            indexPathForSelectedRow == indexPath {
            tableView.deselectRow(at: indexPath, animated: false)
            return nil
        }
        return indexPath
    }
}

// MARK: - DataSource
extension ManageMembershipViewController {
    private func configureDataSource() -> RxTableViewSectionedReloadDataSource<SectionModel<String, MembershipModel>> {
        return RxTableViewSectionedReloadDataSource<SectionModel<String, MembershipModel>>(
            // cell 설정
            configureCell: { dataSource, tableView, indexPath, model in
                let cell: ManageMembershipTableViewCell = tableView.dequeueReusableCell(forIndexPath: indexPath)
                cell.configure(with: model)
                return cell
            },
            // swipe 액션 사용
            canEditRowAtIndexPath: { (_, _) in
                return true
            })
    }
}

// MARK: - Private Method
extension ManageMembershipViewController {
    private func openDeletePopup(uri: String, membership: MembershipModel) {
        let alertController = UIAlertController(title: nil, message: LocalizationKey.popup_title_delete_membership.localized(), preferredStyle: .alert)
        let cancelButton = UIAlertAction(title: LocalizationKey.cancel.localized(), style: .cancel)
        let confirmButton = UIAlertAction(title: LocalizationKey.confirm.localized(), style: .default) { [weak self] _ in
            guard let membershipId = membership.id else { return }
            self?.deleteMembership.onNext((uri, membershipId))
        }

        alertController.addAction(confirmButton)
        alertController.addAction(cancelButton)

        self.present(alertController, animated: true, completion: nil)

        let vc = CreateMembershipViewController.make(uri: uri, membership: membership)
        if let topViewController = UIApplication.topViewController() {
            topViewController.openViewController(vc, type: .push)
        }
    }
}
