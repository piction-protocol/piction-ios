//
//  ManageSponsorshipPlanViewController.swift
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

protocol ManageSponsorshipPlanDelegate: class {
    func selectSponsorshipPlan(with plan: PlanModel?)
}

final class ManageSponsorshipPlanViewController: UIViewController {
    var disposeBag = DisposeBag()

    @IBOutlet weak var closeButton: UIBarButtonItem!
    @IBOutlet weak var createButton: UIBarButtonItem!
    @IBOutlet weak var tableView: UITableView!

    weak var delegate: ManageSponsorshipPlanDelegate?

    private let deleteSponsorshipPlan = PublishSubject<(String, Int)>()

    override func viewDidLoad() {
        super.viewDidLoad()
        self.navigationController?.configureNavigationBar(transparent: false, shadow: true)
    }

    private func configureDataSource() -> RxTableViewSectionedReloadDataSource<SectionModel<String, PlanModel>> {
        return RxTableViewSectionedReloadDataSource<SectionModel<String, PlanModel>>(
            configureCell: { dataSource, tableView, indexPath, model in
                let cell: ManageSponsorshipPlanTableViewCell = tableView.dequeueReusableCell(forIndexPath: indexPath)
                cell.configure(with: model)
                return cell
        }, canEditRowAtIndexPath: { (_, _) in
            return true
        })
    }

    private func openDeletePopup(uri: String, sponsorshipPlan: PlanModel) {
        let alertController = UIAlertController(title: nil, message: LocalizationKey.popup_title_delete_sponsorship_plan.localized(), preferredStyle: .alert)
        let cancelButton = UIAlertAction(title: LocalizationKey.cancel.localized(), style: .cancel)
        let confirmButton = UIAlertAction(title: LocalizationKey.confirm.localized(), style: .default) { [weak self] _ in
            guard let planId = sponsorshipPlan.id else { return }
            self?.deleteSponsorshipPlan.onNext((uri, planId))
        }

        alertController.addAction(confirmButton)
        alertController.addAction(cancelButton)

        self.present(alertController, animated: true, completion: nil)

        let vc = CreateSponsorshipPlanViewController.make(uri: uri, sponsorshipPlan: sponsorshipPlan)
        if let topViewController = UIApplication.topViewController() {
            topViewController.openViewController(vc, type: .push)
        }
    }
}

extension ManageSponsorshipPlanViewController: ViewModelBindable {
    typealias ViewModel = ManageSponsorshipPlanViewModel

    func bindViewModel(viewModel: ViewModel) {
        let dataSource = configureDataSource()

        tableView.rx.setDelegate(self)
            .disposed(by: disposeBag)

        let input = ManageSponsorshipPlanViewModel.Input(
            viewWillAppear: rx.viewWillAppear.asDriver(),
            selectedIndexPath: tableView.rx.itemSelected.asDriver(),
            createBtnDidTap: createButton.rx.tap.asDriver(),
            deleteSponsorshipPlan: deleteSponsorshipPlan.asDriver(onErrorDriveWith: .empty()),
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
            .sponsorshipPlanList
            .drive { $0 }
            .map { [SectionModel(model: "sponsorshipPlan", items: $0)] }
            .bind(to: tableView.rx.items(dataSource: dataSource))
            .disposed(by: disposeBag)

        output
            .sponsorshipPlanList
            .drive(onNext: { [weak self] sponsorshipPlanList in
                let selectedSponsorshipPlanId = self?.viewModel?.planId ?? 0
                guard let seriesIndex = sponsorshipPlanList.firstIndex(where: { $0.id == selectedSponsorshipPlanId }) else { return }
                let indexPath = IndexPath(row: seriesIndex, section: 0)
                self?.tableView.selectRow(at: indexPath, animated: false, scrollPosition: .middle)
            })
            .disposed(by: disposeBag)

        output
            .selectedIndexPath
            .drive(onNext: { [weak self] indexPath in
                guard let delegate = self?.delegate else { return }
                let sponsorshipPlan = dataSource[indexPath]
                delegate.selectSponsorshipPlan(with: sponsorshipPlan)
            })
            .disposed(by: disposeBag)

        output
            .openCreateSponsorshipPlanViewController
            .drive(onNext: { [weak self] uri in
                self?.openCreateSponsorshipPlanViewController(uri: uri)
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
                    action: LocalizationKey.retry.localized()) { [weak self] in
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

extension ManageSponsorshipPlanViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let editAction = UIContextualAction(style: .normal, title: LocalizationKey.edit.localized(), handler: { [weak self] (action, view, completionHandler) in
            guard let uri = self?.viewModel?.uri else { return }
            if let sponsorshipPlan: PlanModel = try? self?.tableView.rx.model(at: indexPath) {
                self?.openCreateSponsorshipPlanViewController(uri: uri, sponsorshipPlan: sponsorshipPlan)
                completionHandler(true)
            }
        })
        let deleteAction = UIContextualAction(style: .destructive, title: LocalizationKey.delete.localized(), handler: { [weak self] (action, view, completionHandler) in
            guard let uri = self?.viewModel?.uri else { return }
            if let sponsorshipPlan: PlanModel = try? self?.tableView.rx.model(at: indexPath) {
                self?.openDeletePopup(uri: uri, sponsorshipPlan: sponsorshipPlan)
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
