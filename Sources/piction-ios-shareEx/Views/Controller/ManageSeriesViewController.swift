//
//  ManageSeriesViewController.swift
//  piction-ios-shareEx
//
//  Created by jhseo on 2019/11/06.
//  Copyright © 2019 Piction Network. All rights reserved.
//

import UIKit
import RxSwift
import RxCocoa
import ViewModelBindable
import RxDataSources
import PictionSDK

// 현재 사용하지 않는 화면입니다. (에디터 기능 지원안함)

protocol ManageSeriesDelegate: class {
    func selectSeries(with series: SeriesModel?)
}

final class ManageSeriesViewController: UIViewController {
    var disposeBag = DisposeBag()

    @IBOutlet weak var emptyView: UIView!

    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var closeButton: UIBarButtonItem!
    @IBOutlet weak var createButton: UIButton!

    weak var delegate: ManageSeriesDelegate?

    private let updateSeries = PublishSubject<(String, SeriesModel?)>()
    private let contextualAction = PublishSubject<(UIContextualAction.Style, IndexPath)>()
    private let deleteConfirm = PublishSubject<Int>()

    private func embedCustomEmptyViewController(style: EmptyViewStyle) {
        _ = emptyView.subviews.map { $0.removeFromSuperview() }
        emptyView.frame.size.height = view.frame.size.height
        let vc = EmptyViewController.make(style: style)
        embed(vc, to: emptyView)
    }

    private func configureDataSource() -> RxTableViewSectionedReloadDataSource<SectionModel<String, SeriesModel>> {
        return RxTableViewSectionedReloadDataSource<SectionModel<String, SeriesModel>>(
            // cell 설정
            configureCell: { dataSource, tableView, indexPath, model in
                let cell: ManageSeriesTableViewCell = tableView.dequeueReusableCell(forIndexPath: indexPath)
                cell.configure(with: model)
                return cell
            },
            // swipe 액션 사용 (에디터 기능 지원 안함)
            canEditRowAtIndexPath: { (_, _) in
                return true
            })
    }

    private func openDeleteConfirmPopup(seriesId: Int) {
        let alertController = UIAlertController(
            title: LocalizationKey.str_delete_series.localized(),
            message: nil,
            preferredStyle: UIAlertController.Style.alert)

            let deleteAction = UIAlertAction(
                title: LocalizationKey.delete.localized(),
                style: UIAlertAction.Style.destructive,
                handler: { [weak self] action in
                    self?.deleteConfirm.onNext(seriesId)
                })

            let cancelAction = UIAlertAction(
                title: LocalizationKey.cancel.localized(),
                style:UIAlertAction.Style.cancel,
                handler:{ action in
                })

            alertController.addAction(deleteAction)
            alertController.addAction(cancelAction)

            present(alertController, animated: true, completion: nil)
    }

    private func openUpdateSeriesPopup(series: SeriesModel?) {
        let alertController = UIAlertController(
            title: series == nil ? LocalizationKey.str_add_series.localized() : LocalizationKey.str_modify_series.localized(),
            message: nil,
            preferredStyle: UIAlertController.Style.alert)

        alertController.addTextField(configurationHandler: { textField in
            textField.clearButtonMode = UITextField.ViewMode.always
            textField.text = series == nil ? "" : series?.name ?? ""
        })

        let insertAction = UIAlertAction(
            title: series == nil ? LocalizationKey.create.localized() : LocalizationKey.str_modify.localized(),
            style: UIAlertAction.Style.default,
            handler: { [weak self] action in
                guard let textFields = alertController.textFields else {
                    return
                }
                self?.updateSeries.onNext((textFields[0].text ?? "", series))
            })

        let cancelAction = UIAlertAction(
            title: LocalizationKey.cancel.localized(),
            style:UIAlertAction.Style.cancel,
            handler:{ action in
            })

        alertController.addAction(insertAction)
        alertController.addAction(cancelAction)

        present(alertController, animated: true, completion: nil)
    }
}

extension ManageSeriesViewController: ViewModelBindable {
    typealias ViewModel = ManageSeriesViewModel

    func bindViewModel(viewModel: ViewModel) {
        let dataSource = configureDataSource()

        let input = ManageSeriesViewModel.Input(
            viewWillAppear: rx.viewWillAppear.asDriver(),
            selectedIndexPath: tableView.rx.itemSelected.asDriver(),
            createBtnDidTap: createButton.rx.tap.asDriver(),
            contextualAction: contextualAction.asDriver(onErrorDriveWith: .empty()),
            deleteConfirm: deleteConfirm.asDriver(onErrorDriveWith: .empty()),
            updateSeries: updateSeries.asDriver(onErrorDriveWith: .empty()),
            closeBtnDidTap: closeButton.rx.tap.asDriver()
        )

        let output = viewModel.build(input: input)

        output
            .viewWillAppear
            .drive(onNext: { [weak self] _ in
                self?.navigationController?.configureNavigationBar(transparent: false, shadow: true)
                self?.tableView.allowsSelection = self?.delegate != nil
                let uri = self?.viewModel?.uri ?? ""
                FirebaseManager.screenName("공유_시리즈목록_\(uri)")
            })
            .disposed(by: disposeBag)

        output
            .seriesList
            .do(onNext: { [weak self] _ in
                _ = self?.emptyView.subviews.map { $0.removeFromSuperview() }
                self?.emptyView.frame.size.height = 0
            })
            .drive { $0 }
            .map { [SectionModel(model: "series", items: $0)] }
            .bind(to: tableView.rx.items(dataSource: dataSource))
            .disposed(by: disposeBag)

        output
            .selectedIndexPath
            .drive(onNext: { [weak self] indexPath in
                guard let delegate = self?.delegate else { return }
                let series = dataSource[indexPath]
                delegate.selectSeries(with: series)
                self?.dismiss(animated: true)
            })
            .disposed(by: disposeBag)

        output
            .openUpdateSeriesPopup
            .drive(onNext: { [weak self] indexPath in
                var series: SeriesModel? {
                    if let indexPath = indexPath {
                        return dataSource[indexPath]
                    } else {
                        return nil
                    }
                }
                self?.openUpdateSeriesPopup(series: series)
            })
            .disposed(by: disposeBag)

        output
            .openDeleteConfirmPopup
            .drive(onNext: { [weak self] indexPath in
                guard let seriesId = dataSource[indexPath].id else { return }
                self?.openDeleteConfirmPopup(seriesId: seriesId)
            })
            .disposed(by: disposeBag)

        // emptyView 출력
        output
            .embedEmptyViewController
            .drive(onNext: { [weak self] style in
                guard let `self` = self else { return }
                self.embedCustomEmptyViewController(style: style)
            })
            .disposed(by: disposeBag)

        // 화면을 닫음
        output
            .dismissViewController
            .drive(onNext: { [weak self] _ in
                self?.dismiss(animated: true)
            })
            .disposed(by: disposeBag)
    }
}

extension ManageSeriesViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let editAction = UIContextualAction(style: .normal, title: LocalizationKey.edit.localized(), handler: { [weak self] (action, view, completionHandler) in
            self?.contextualAction.onNext((action.style, indexPath))
            completionHandler(true)
        })

        let deleteAction = UIContextualAction(style: .destructive, title: LocalizationKey.delete.localized(), handler: { [weak self] (action, view, completionHandler) in
            self?.contextualAction.onNext((action.style, indexPath))
            completionHandler(true)
        })

        return UISwipeActionsConfiguration(actions: [deleteAction, editAction])
    }

    func tableView(_ tableView: UITableView, willSelectRowAt indexPath: IndexPath) -> IndexPath? {
        if let indexPathForSelectedRow = tableView.indexPathForSelectedRow,
            indexPathForSelectedRow == indexPath {
            tableView.deselectRow(at: indexPath, animated: false)
            return nil
        }
        return indexPath
    }

    func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCell.EditingStyle {
        return .none
    }

    func tableView(_ tableView: UITableView, shouldIndentWhileEditingRowAt indexPath: IndexPath) -> Bool {
        return false
    }
}
