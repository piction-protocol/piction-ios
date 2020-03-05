//
//  CreatorProfileViewController.swift
//  piction-ios
//
//  Created by jhseo on 2020/02/18.
//  Copyright © 2020 Piction Network. All rights reserved.
//

import UIKit
import RxSwift
import RxCocoa
import ViewModelBindable
import RxDataSources
import PictionSDK

// MARK: - UIViewController
final class CreatorProfileViewController: UIViewController {
    var disposeBag = DisposeBag()

    var creatorProfileHeaderView: CreatorProfileHeaderViewController?

    @IBOutlet weak var collectionView: UICollectionView! {
        didSet {
            // ProjectListCollectionViewCell은 공통으로 사용하여 storyboard가 아닌 여기서 등록
            collectionView.registerXib(ProjectListCollectionViewCell.self)
            // collectionView header 추가
            collectionView.registerReusableView(ReuseCollectionReusableView.self, kind: .header)
            // UI가 완전히 보여지기 전까지는 숨김
            collectionView.isHidden = true
        }
    }

    deinit {
        // 메모리 해제되는지 확인
        print("[deinit] \(String(describing: type(of: self)))")
    }
}

// MARK: - ViewModelBindable
extension CreatorProfileViewController: ViewModelBindable {
    typealias ViewModel = CreatorProfileViewModel

    func bindViewModel(viewModel: ViewModel) {
        let dataSource = configureDataSource()

        let input = CreatorProfileViewModel.Input(
            viewWillAppear: rx.viewWillAppear.asDriver(), // 화면이 보여지기 전에
            viewWillLayoutSubviews: rx.viewWillLayoutSubviews.asDriver(), // subview의 layout이 갱신되기 전에
            selectedIndexPath: collectionView.rx.itemSelected.asDriver() // collectionView의 item을 눌렀을 때
        )

        let output = viewModel.build(input: input)

        // 화면이 보여지기 전에 NavigationBar 설정
        output
            .viewWillAppear
            .drive(onNext: { [weak self] in
                self?.navigationController?.configureNavigationBar(transparent: false, shadow: true)
            })
            .disposed(by: disposeBag)

        // subview의 layout이 갱신되기 전에
        output
            .viewWillLayoutSubviews
            .drive(onNext: { [weak self] in
                self?.changeLayoutSubviews()
            })
            .disposed(by: disposeBag)

        // CreatorProfileHeader를 생성
        output
            .embedCreatorProfileHeaderViewController
            .drive(onNext: { [weak self] in
                self?.embedCreatorProfileHeaderViewController(loginId: $0)
            })
            .disposed(by: disposeBag)

        // Creator의 Project List를 CollectionView에 출력
        output
            .creatorProjectList
            .drive { $0 }
            .map { [SectionModel(model: "", items: $0)] }
            .bind(to: collectionView.rx.items(dataSource: dataSource))
            .disposed(by: disposeBag)

        // Creator의 Project List를 CollectionView에 출력 후 layout 변경이 필요하다면 변경
        output
            .creatorProjectList
            .drive(onNext: { [weak self] _ in
                self?.collectionView.layoutIfNeeded()
            })
            .disposed(by: disposeBag)

        // collectionView의 item을 선택할 때
        output
            .selectedIndexPath
            .map { dataSource[$0].uri }
            .filter { $0 != nil }
            .flatMap(Driver.from)
            .map { .project(uri: $0) }
            .drive(onNext: { [weak self] in
                self?.openView(type: $0, openType: .push)
            })
            .disposed(by: disposeBag)

        // 로딩 뷰
        output
            .activityIndicator
            .loadingActivity()
            .disposed(by: disposeBag)

        // Creator 정보가 없으면 Popup 출력하고 확인 누르면 Pop
        output
            .popViewController
            .drive(onNext: { [weak self] message in
                self?.showPopup(
                title: nil,
                message: message,
                action: [LocalizationKey.confirm.localized()]) { [weak self] in
                    self?.navigationController?.popViewController(animated: true)
                }
            })
            .disposed(by: disposeBag)
    }
}

// MARK: - CreatorHeaderViewDelegate
extension CreatorProfileViewController: CreatorHeaderViewDelegate {
    // Header의 로딩이 끝나면 CollectionView를 reload하고 숨김해제 (Header 사이즈 변경으로 레이아웃이 틀어지는 현상을 보여주지 않고 자연스럽게 보여지기 위함)
    func loadComplete() {
        collectionView.reloadData()
        collectionView.isHidden = false
    }

    // 불필요하게 현재 viewModel에서 creator 정보를 호출하지 않고 header에서 받아와서 navigation title을 변경
    func setNavigationTitle(title: String) {
        self.navigationItem.title = title
    }
}

// MARK: - UICollectionViewDelegateFlowLayout
extension CreatorProfileViewController: UICollectionViewDelegateFlowLayout {
    // creatorProfileHeaderView의 실제 Size를 계산해서 해당 size만큼 collectionView header의 size로 설정
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, referenceSizeForHeaderInSection section: Int) -> CGSize {
        let defaultHeight: CGFloat = 264.5

        if let headerView = creatorProfileHeaderView {
            let height = headerView.view.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize).height
            let linkCollectionViewHeight = headerView.linkCollectionView.contentSize.height
            let greetingHeight = headerView.greetingTextView.sizeThatFits(CGSize(width: headerView.view.frame.size.width - 32, height: CGFloat.greatestFiniteMagnitude)).height
            return CGSize(width: view.frame.size.width, height: height + greetingHeight + linkCollectionViewHeight)
        }
        return CGSize(width: view.frame.size.width, height: defaultHeight)
     }
}

// MARK: - DataSource
extension CreatorProfileViewController {
    private func configureDataSource() -> RxCollectionViewSectionedReloadDataSource<SectionModel<String, ProjectModel>> {
        return RxCollectionViewSectionedReloadDataSource<SectionModel<String, ProjectModel>>(
            // cell 설정
            configureCell: { dataSource, collectionView, indexPath, model in
                let cell: ProjectListCollectionViewCell = collectionView.dequeueReusableCell(forIndexPath: indexPath)
                cell.configure(with: model)
                return cell
            },
            // header, footer 설정
            configureSupplementaryView: { [weak self] (dataSource, collectionView, kind, indexPath) in
                guard let `self` = self else { return UICollectionReusableView() }

                switch kind {
                case UICollectionView.elementKindSectionHeader:
                    let reusableView = collectionView.dequeueReusableView(ReuseCollectionReusableView.self, indexPath: indexPath, kind: .header)

                    // subview가 없는 경우에만 header를 embed
                    if reusableView.subviews.isEmpty {
                        if let creatorProfileHeaderView = self.creatorProfileHeaderView {
                            self.embed(creatorProfileHeaderView, to: reusableView)
                        }
                    }
                    reusableView.layoutIfNeeded()
                    return reusableView
                default:
                    return UICollectionReusableView()
                }
            })
    }
}

// MARK: - Private Method
extension CreatorProfileViewController {
    // Pad에서 가로/세로모드 변경 시 cell size 변경 (pad 가로모드에서는 한줄에 4개의 cell을 보여주도록 함)
    private func changeLayoutSubviews() {
        if let flowLayout = collectionView.collectionViewLayout as? UICollectionViewFlowLayout {
            let cellCount: CGFloat = UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiom.pad && view.frame.size.width == UIScreen.main.bounds.size.width ? 4 : 2
            let width = (view.frame.size.width - 40 - (cellCount - 1) * 7) / cellCount
            let height = width + 44
            flowLayout.itemSize = CGSize(width: width, height: height)
            flowLayout.invalidateLayout()
            collectionView.layoutIfNeeded()
        }
    }

    // CreatorProfileHeader를 생성
    private func embedCreatorProfileHeaderViewController(loginId: String) {
        creatorProfileHeaderView = CreatorProfileHeaderViewController.make(loginId: loginId)
        creatorProfileHeaderView?.delegate = self
    }
}
