//
//  ManageFanPassViewController.swift
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

protocol ManageFanPassDelegate: class {
    func selectFanPass(with series: FanPassModel?)
}

final class ManageFanPassViewController: UIViewController {
    var disposeBag = DisposeBag()

    @IBOutlet weak var closeButton: UIBarButtonItem!
    @IBOutlet weak var createButton: UIBarButtonItem!
    @IBOutlet weak var tableView: UITableView!

    weak var delegate: ManageFanPassDelegate?

    private let deleteFanPass = PublishSubject<(String, Int)>()

    override func viewDidLoad() {
        super.viewDidLoad()
        self.navigationController?.configureNavigationBar(transparent: false, shadow: true)
    }

    private func configureDataSource() -> RxTableViewSectionedReloadDataSource<SectionModel<String, FanPassModel>> {
        return RxTableViewSectionedReloadDataSource<SectionModel<String, FanPassModel>>(
            configureCell: { dataSource, tableView, indexPath, model in
                let cell: ManageFanPassTableViewCell = tableView.dequeueReusableCell(forIndexPath: indexPath)
                cell.configure(with: model)
                return cell
        }, canEditRowAtIndexPath: { (_, _) in
            return true
        })
    }

    private func openCreateFanPassViewController(uri: String, fanPass: FanPassModel? = nil) {
        let vc = CreateFanPassViewController.make(uri: uri, fanPass: fanPass)
        if let topViewController = UIApplication.topViewController() {
            topViewController.openViewController(vc, type: .push)
        }
    }

    private func openDeletePopup(uri: String, fanPass: FanPassModel) {
        let alertController = UIAlertController(title: nil, message: LocalizedStrings.popup_title_delete_fanpass.localized(), preferredStyle: .alert)
        let cancelButton = UIAlertAction(title: LocalizedStrings.cancel.localized(), style: .cancel)
        let confirmButton = UIAlertAction(title: LocalizedStrings.confirm.localized(), style: .default) { [weak self] _ in
            guard let fanPassId = fanPass.id else { return }
            self?.deleteFanPass.onNext((uri, fanPassId))
        }

        alertController.addAction(confirmButton)
        alertController.addAction(cancelButton)

        self.present(alertController, animated: true, completion: nil)

        let vc = CreateFanPassViewController.make(uri: uri, fanPass: fanPass)
        if let topViewController = UIApplication.topViewController() {
            topViewController.openViewController(vc, type: .push)
        }
    }
}

extension ManageFanPassViewController: ViewModelBindable {
    typealias ViewModel = ManageFanPassViewModel

    func bindViewModel(viewModel: ViewModel) {
        let dataSource = configureDataSource()

        tableView.rx.setDelegate(self)
            .disposed(by: disposeBag)

        let input = ManageFanPassViewModel.Input(
            viewWillAppear: rx.viewWillAppear.asDriver(),
            selectedIndexPath: tableView.rx.itemSelected.asDriver(),
            createBtnDidTap: createButton.rx.tap.asDriver(),
            deleteFanPass: deleteFanPass.asDriver(onErrorDriveWith: .empty()),
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
            .fanPassList
            .drive { $0 }
            .map { [SectionModel(model: "fanPass", items: $0)] }
            .bind(to: tableView.rx.items(dataSource: dataSource))
            .disposed(by: disposeBag)

        output
            .fanPassList
            .drive(onNext: { [weak self] fanPassList in
                let selectedFanPassId = self?.viewModel?.fanPassId ?? 0
                guard let seriesIndex = fanPassList.firstIndex(where: { $0.id == selectedFanPassId }) else { return }
                let indexPath = IndexPath(row: seriesIndex, section: 0)
                self?.tableView.selectRow(at: indexPath, animated: false, scrollPosition: .middle)
            })
            .disposed(by: disposeBag)

        output
            .selectedIndexPath
            .drive(onNext: { [weak self] indexPath in
                guard let delegate = self?.delegate else { return }
                let fanPass = dataSource[indexPath]
                delegate.selectFanPass(with: fanPass)
            })
            .disposed(by: disposeBag)

        output
            .openCreateFanPassViewController
            .drive(onNext: { [weak self] uri in
                self?.openCreateFanPassViewController(uri: uri)
            })
            .disposed(by: disposeBag)

        output
            .activityIndicator
            .drive(onNext: { status in
                Toast.loadingActivity(status)
            })
            .disposed(by: disposeBag)

        output
            .showErrorPopup
            .drive(onNext: { [weak self] in
                Toast.loadingActivity(false)
                self?.showPopup(
                    title: LocalizedStrings.popup_title_network_error.localized(),
                    message: LocalizedStrings.msg_api_internal_server_error.localized(),
                    action: LocalizedStrings.retry.localized()) { [weak self] in
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
            .showToast
            .drive(onNext: { message in
                Toast.showToast(message)
            })
            .disposed(by: disposeBag)
    }
}

extension ManageFanPassViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let editAction = UIContextualAction(style: .normal, title: LocalizedStrings.edit.localized(), handler: { [weak self] (action, view, completionHandler) in
            guard let uri = self?.viewModel?.uri else { return }
            if let fanPass: FanPassModel = try? self?.tableView.rx.model(at: indexPath) {
                self?.openCreateFanPassViewController(uri: uri, fanPass: fanPass)
                completionHandler(true)
            }
        })
        let deleteAction = UIContextualAction(style: .destructive, title: LocalizedStrings.delete.localized(), handler: { [weak self] (action, view, completionHandler) in
            guard let uri = self?.viewModel?.uri else { return }
            if let fanPass: FanPassModel = try? self?.tableView.rx.model(at: indexPath) {
                self?.openDeletePopup(uri: uri, fanPass: fanPass)
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
