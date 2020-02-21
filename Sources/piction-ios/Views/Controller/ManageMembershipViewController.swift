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

protocol ManageMembershipDelegate: class {
    func selectMembership(with membership: MembershipModel?)
}

final class ManageMembershipViewController: UIViewController {
    var disposeBag = DisposeBag()

    @IBOutlet weak var closeButton: UIBarButtonItem!
    @IBOutlet weak var createButton: UIBarButtonItem!
    @IBOutlet weak var tableView: UITableView!

    weak var delegate: ManageMembershipDelegate?

    private let deleteMembership = PublishSubject<(String, Int)>()

    override func viewDidLoad() {
        super.viewDidLoad()
        self.navigationController?.configureNavigationBar(transparent: false, shadow: true)
    }

    private func configureDataSource() -> RxTableViewSectionedReloadDataSource<SectionModel<String, MembershipModel>> {
        return RxTableViewSectionedReloadDataSource<SectionModel<String, MembershipModel>>(
            configureCell: { dataSource, tableView, indexPath, model in
                let cell: ManageMembershipTableViewCell = tableView.dequeueReusableCell(forIndexPath: indexPath)
                cell.configure(with: model)
                return cell
        }, canEditRowAtIndexPath: { (_, _) in
            return true
        })
    }

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

extension ManageMembershipViewController: ViewModelBindable {
    typealias ViewModel = ManageMembershipViewModel

    func bindViewModel(viewModel: ViewModel) {
        let dataSource = configureDataSource()

        tableView.rx.setDelegate(self)
            .disposed(by: disposeBag)

        let input = ManageMembershipViewModel.Input(
            viewWillAppear: rx.viewWillAppear.asDriver(),
            selectedIndexPath: tableView.rx.itemSelected.asDriver(),
            createBtnDidTap: createButton.rx.tap.asDriver(),
            deleteMembership: deleteMembership.asDriver(onErrorDriveWith: .empty()),
            closeBtnDidTap: closeButton.rx.tap.asDriver()
        )

        let output = viewModel.build(input: input)

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
            .drive(onNext: { [weak self] uri in
                self?.openCreateMembershipViewController(uri: uri)
            })
            .disposed(by: disposeBag)

        output
            .activityIndicator
            .loadingActivity()
            .disposed(by: disposeBag)

        output
            .showErrorPopup
            .drive(onNext: { [weak self] in
                Toast.loadingActivity(false)
                self?.showPopup(
                    title: LocalizationKey.popup_title_network_error.localized(),
                    message: LocalizationKey.msg_api_internal_server_error.localized(),
                    action: [LocalizationKey.retry.localized(), LocalizationKey.cancel.localized()]) { [weak self] in
                        self?.viewModel?.loadRetryTrigger.onNext(())
                    }
            })
            .disposed(by: disposeBag)

        output
            .dismissViewController
            .drive(onNext: { [weak self] message in
                self?.dismiss(animated: true)
            })
            .disposed(by: disposeBag)

        output
            .toastMessage
            .showToast()
            .disposed(by: disposeBag)
    }
}

extension ManageMembershipViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let editAction = UIContextualAction(style: .normal, title: LocalizationKey.edit.localized(), handler: { [weak self] (action, view, completionHandler) in
            guard let uri = self?.viewModel?.uri else { return }
            if let membership: MembershipModel = try? self?.tableView.rx.model(at: indexPath) {
                self?.openCreateMembershipViewController(uri: uri, membership: membership)
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
