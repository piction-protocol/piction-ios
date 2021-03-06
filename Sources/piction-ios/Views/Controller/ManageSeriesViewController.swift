//
//  ManageSeriesViewController.swift
//  piction-ios
//
//  Created by jhseo on 2019/10/25.
//  Copyright © 2019 Piction Network. All rights reserved.
//

import UIKit
import RxSwift
import RxCocoa
import ViewModelBindable
import RxDataSources
import PictionSDK

// 현재 사용하지 않는 화면입니다. (에디터 기능 지원안함)

// MARK: - ManageSeriesDelegate
protocol ManageSeriesDelegate: class {
    func selectSeries(with series: SeriesModel?)
}

// MARK: - UIViewController
final class ManageSeriesViewController: UIViewController {
    var disposeBag = DisposeBag()

    @IBOutlet weak var emptyView: UIView!

    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var closeButton: UIBarButtonItem!
    @IBOutlet weak var createButton: UIButton!
    @IBOutlet weak var reorderButton: UIBarButtonItem!

    weak var delegate: ManageSeriesDelegate?

    private let updateSeries = PublishSubject<(Int?, String)>()
    private let contextualAction = PublishSubject<(UIContextualAction.Style, IndexPath)>()
    private let deleteConfirm = PublishSubject<Int>()
    private let reorderItems = PublishSubject<[Int]>()

    deinit {
        // 메모리 해제되는지 확인
        print("[deinit] \(String(describing: type(of: self)))")
    }
}

// MARK: - ViewModelBindable
extension ManageSeriesViewController: ViewModelBindable {
    typealias ViewModel = ManageSeriesViewModel

    func bindViewModel(viewModel: ViewModel) {
        let dataSource = configureDataSource()

        tableView.rx.setDelegate(self)
            .disposed(by: disposeBag)

        let input = ManageSeriesViewModel.Input(
            viewWillAppear: rx.viewWillAppear.asDriver(),
            viewWillDisappear: rx.viewWillDisappear.asDriver(),
            selectedIndexPath: tableView.rx.itemSelected.asDriver(),
            reorderBtnDidTap: reorderButton.rx.tap.asDriver(),
            createBtnDidTap: createButton.rx.tap.asDriver(),
            contextualAction: contextualAction.asDriver(onErrorDriveWith: .empty()),
            deleteConfirm: deleteConfirm.asDriver(onErrorDriveWith: .empty()),
            updateSeries: updateSeries.asDriver(onErrorDriveWith: .empty()),
            reorderItems: reorderItems.asDriver(onErrorDriveWith: .empty()),
            closeBtnDidTap: closeButton.rx.tap.asDriver()
        )

        let output = viewModel.build(input: input)

        // 화면이 보여지기 전에 NavigationBar 설정
        output
            .viewWillAppear
            .drive(onNext: { [weak self] _ in
                self?.navigationController?.configureNavigationBar(transparent: false, shadow: true)
                self?.tableView.allowsSelection = self?.delegate != nil
                self?.tableView.allowsSelectionDuringEditing = self?.delegate != nil
            })
            .disposed(by: disposeBag)

        output
            .viewWillDisappear
            .drive(onNext: { [weak self] _ in
                if let selectedIndexPath = self?.tableView.indexPathForSelectedRow {
                    let series = dataSource[selectedIndexPath]
                    self?.delegate?.selectSeries(with: series)
                } else {
                    self?.delegate?.selectSeries(with: nil)
                }
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
            .seriesList
            .drive(onNext: { [weak self] seriesList in
                let selectedSeriesId = self?.viewModel?.seriesId ?? 0
                guard let seriesIndex = seriesList.firstIndex(where: { $0.id == selectedSeriesId }) else { return }
                let indexPath = IndexPath(row: seriesIndex, section: 0)
                self?.tableView.selectRow(at: indexPath, animated: false, scrollPosition: .middle)
            })
            .disposed(by: disposeBag)

        output
            .selectedIndexPath
            .drive(onNext: { [weak self] indexPath in
                guard let delegate = self?.delegate else { return }
                let series = dataSource[indexPath]
                delegate.selectSeries(with: series)
            })
            .disposed(by: disposeBag)

        output
            .changeEditMode
            .drive(onNext: { [weak self] _ in
                guard let isEditing = self?.tableView.isEditing else { return }

                if isEditing {
                    guard let models = dataSource.sectionModels[safe: 0]?.items else { return }
                    let reorderItems = models.map { $0.id ?? 0 }
                    self?.reorderItems.onNext(reorderItems)
                }

                self?.reorderButton.title = isEditing ? LocalizationKey.str_sort.localized() : LocalizationKey.str_completed.localized()
                self?.tableView.setEditing(!isEditing, animated: true)
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
            .map { dataSource[$0].id }
            .flatMap(Driver.from)
            .drive(onNext: { [weak self] in
                self?.openDeleteConfirmPopup(seriesId: $0)
            })
            .disposed(by: disposeBag)

        // emptyView 출력
        output
            .embedEmptyViewController
            .drive(onNext: { [weak self] in
                self?.embedCustomEmptyViewController(style: $0)
            })
            .disposed(by: disposeBag)

        // 토스트 메시지 출력
        output
            .toastMessage
            .showToast()
            .disposed(by: disposeBag)

        // 로딩 뷰
        output
            .activityIndicator
            .loadingActivity()
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

// MARK: - UITableViewDelegate
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

// MARK: - DataSource
extension ManageSeriesViewController {
    private func configureDataSource() -> RxTableViewSectionedReloadDataSource<SectionModel<String, SeriesModel>> {
        return RxTableViewSectionedReloadDataSource<SectionModel<String, SeriesModel>>(
            // cell 설정
            configureCell: { dataSource, tableView, indexPath, model in
                let cell: ManageSeriesTableViewCell = tableView.dequeueReusableCell(forIndexPath: indexPath)
                cell.configure(with: model)
                return cell
            },
            // swipe 액션 사용
            canEditRowAtIndexPath: { (_, _) in
                return true
            },
            // cell 순서 변경
            canMoveRowAtIndexPath: { (dataSource, indexPath) in
                return true
            })
    }
}

// MARK: - Private Method
extension ManageSeriesViewController {
    // emptyView를 embed
    private func embedCustomEmptyViewController(style: CustomEmptyViewStyle) {
        _ = emptyView.subviews.map { $0.removeFromSuperview() }
        emptyView.frame.size.height = visibleHeight
        let vc = CustomEmptyViewController.make(style: style)
        embed(vc, to: emptyView)
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
                self?.updateSeries.onNext((series?.id, textFields[0].text ?? ""))
            })

        let cancelAction = UIAlertAction(
            title: LocalizationKey.cancel.localized(),
            style: UIAlertAction.Style.cancel,
            handler: { action in
            })

        alertController.addAction(insertAction)
        alertController.addAction(cancelAction)

        present(alertController, animated: true, completion: nil)
    }
}
