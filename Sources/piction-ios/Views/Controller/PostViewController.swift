//
//  PostViewController.swift
//  PictionView
//
//  Created by jhseo on 01/07/2019.
//  Copyright © 2019 Piction Network. All rights reserved.
//

import UIKit
import RxSwift
import RxCocoa
import ViewModelBindable
import Swinject
import WebKit
import SafariServices
import PictionSDK
import RxGesture

final class PostViewController: UIViewController {
    var disposeBag = DisposeBag()

    @IBOutlet weak var subscriptionView: UIView!
    @IBOutlet weak var subscriptionDescriptionLabel: UILabel!
    @IBOutlet weak var subscriptionButton: UIButton!
    @IBOutlet weak var postWebView: WKWebView! {
        didSet {
            postWebView.navigationDelegate = self
            postWebView.scrollView.delegate = self
            postWebView.isOpaque = false
            postWebView.scrollView.contentInsetAdjustmentBehavior = .never
        }
    }
    @IBOutlet weak var prevPostButton: UIButton!
    @IBOutlet weak var nextPostButton: UIButton!
    @IBOutlet weak var shareBarButton: UIBarButtonItem!
    @IBOutlet weak var readmodeBarButton: UIBarButtonItem!

    private let loadPost = PublishSubject<Int>()

    var headerViewController: PostHeaderViewController?
    var footerViewController: PostFooterViewController?

    private func embedPostHeaderViewController(postItem: PostModel, userInfo: UserModel) {
        if let headerView = headerViewController {
            remove(headerView)
        }
        headerViewController = PostHeaderViewController.make(postItem: postItem, userInfo: userInfo)
        let containerView = UIView(frame: CGRect(x: 0, y: 0, width: view.frame.size.width, height: 220))
        containerView.tag = 1000
        embed(headerViewController!, to: containerView)
        self.postWebView.scrollView.addSubview(containerView)
    }

    private func embedPostFooterViewController(height: CGFloat) {
        if let footerView = self.footerViewController {
            remove(footerView)

            let posY = height - 747
            let containerView = UIView(frame: CGRect(x: 0, y: posY, width: view.frame.size.width, height: 747))
            containerView.tag = 1001
            embed(footerView, to: containerView)
            self.postWebView.scrollView.addSubview(containerView)
        }
    }

    private func makePostFooterViewController(uri: String, postItem: PostModel) {
        if let footerView = footerViewController {
            remove(footerView)
        }
        footerViewController = PostFooterViewController.make(uri: uri, postItem: postItem)
        footerViewController?.delegate = self
    }

    private func removeHeaderFooter() {
        for subview in postWebView.scrollView.subviews {
            if subview.tag == 1000 || subview.tag == 1001 {
                subview.removeFromSuperview()
            }
        }
        guard
            let header = headerViewController,
            let footer = footerViewController
        else { return }
        remove(header)
        remove(footer)
    }

    private func resizeFooter() {
        guard
            !postWebView.isLoading,
            self.subscriptionView.isHidden
        else { return }
        postWebView.evaluateJavaScript("document.body.style.marginBottom =\"747px\"", completionHandler: { (complete, error) in
            self.postWebView.evaluateJavaScript("document.body.scrollHeight", completionHandler: { (height, error) in
                if let height = height as? CGFloat {
                    self.embedPostFooterViewController(height: height)
                    self.loadComplete()
                }
            })
        })
    }

    func cacheWebview() {
        postWebView?.stopLoading()
        postWebView?.loadHTMLString("", baseURL: nil)
        URLCache.shared.removeAllCachedResponses()
    }

    func showFullScreen(_ status: Bool = true, animated: Bool = true) {
        let isScrollTop = postWebView.scrollView.contentOffset.y <= -44
        let isScrollBottom = (postWebView.scrollView.contentOffset.y + self.view.frame.size.height) >= self.postWebView.scrollView.contentSize.height
        let fullScreen = (isScrollTop || isScrollBottom) ? false : status
        self.navigationController?.setNavigationBarHidden(fullScreen, animated: animated)
        self.navigationController?.setToolbarHidden(fullScreen, animated: animated)
        self.setNeedsStatusBarAppearanceUpdate()
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)

        if #available(iOS 13.0, *) {
            if previousTraitCollection?.hasDifferentColorAppearance(comparedTo: traitCollection) ?? false {
                setWebviewColor()
            }
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        guard
            let headerView = headerViewController,
            let footerView = footerViewController
        else { return }

        headerView.view.frame.size.width = view.frame.size.width
        footerView.view.frame.size.width = view.frame.size.width
        resizeFooter()
    }

    override var preferredStatusBarUpdateAnimation: UIStatusBarAnimation {
        return .fade
    }
    override var prefersStatusBarHidden: Bool {
        return self.navigationController?.isNavigationBarHidden ?? false
    }

    @available(iOS 13.0, *)
    private func setWebviewColor() {
        let fontColor = UIColor.pictionDarkGrayDM.hexString
        postWebView.evaluateJavaScript("document.getElementsByTagName('body')[0].style.color =\"\(fontColor ?? "#333333")\"")
    }

    private func changeReadmode() {
        if readmodeBarButton.tintColor == .pictionDarkGrayDM {
            let style = [
                "document.getElementsByTagName('body')[0].style.fontFamily =\"RIDIBatang\"",
                "document.getElementsByTagName('body')[0].style.lineHeight =\"35px\"",
                "document.getElementsByTagName('body')[0].style.fontSize =\"18px\"",
                "document.body.style.marginLeft =\"\(SCREEN_W / 8)px\"",
                "document.body.style.marginRight =\"\(SCREEN_W / 8)px\""
            ]
            style.forEach { postWebView.evaluateJavaScript($0) }
            readmodeBarButton.tintColor = UIView().tintColor
        } else {
            let style = [
                "document.getElementsByTagName('body')[0].style.fontFamily =\"Helvetica\"",
                "document.getElementsByTagName('body')[0].style.lineHeight =\"28px\"",
                "document.getElementsByTagName('body')[0].style.fontSize =\"16px\"",
                "document.body.style.marginLeft =\"20px\"",
                "document.body.style.marginRight =\"20px\""
            ]
            style.forEach { postWebView.evaluateJavaScript($0) }
            readmodeBarButton.tintColor = .pictionDarkGrayDM
        }
        resizeFooter()
    }

    deinit {
        cacheWebview()
    }
}

extension PostViewController: ViewModelBindable {
    typealias ViewModel = PostViewModel

    func bindViewModel(viewModel: ViewModel) {

        let input = PostViewModel.Input(
            viewWillAppear: rx.viewWillAppear.asDriver(),
            viewDidAppear: rx.viewDidAppear.asDriver(),
            viewWillDisappear: rx.viewWillDisappear.asDriver(),
            loadPost: loadPost.asDriver(onErrorDriveWith: .empty()),
            prevPostBtnDidTap: prevPostButton.rx.tap.asDriver().throttle(1, latest: true),
            nextPostBtnDidTap: nextPostButton.rx.tap.asDriver().throttle(1, latest: true),
            subscriptionBtnDidTap: subscriptionButton.rx.tap.asDriver(),
            shareBarBtnDidTap: shareBarButton.rx.tap.asDriver(),
            contentOffset: postWebView.scrollView.rx.contentOffset.asDriver(),
            willBeginDecelerating: postWebView.scrollView.rx.willBeginDecelerating.asDriver(),
            readmodeBarButton: readmodeBarButton.rx.tap.asDriver()
        )

        let output = viewModel.build(input: input)

        output
            .viewWillAppear
            .drive(onNext: { [weak self] in
                guard let `self` = self else { return }
                self.navigationController?.configureNavigationBar(transparent: false, shadow: true)
                self.postWebView.scrollView.contentInset = UIEdgeInsets(
                    top: self.statusHeight + DEFAULT_NAVIGATION_HEIGHT,
                    left: 0,
                    bottom: self.toolbarHeight,
                    right: 0)
            })
            .disposed(by: disposeBag)

        output
            .viewDidAppear
            .drive(onNext: { [weak self] in
                self?.navigationController?.toolbar.isHidden = false
            })
            .disposed(by: disposeBag)

        output
            .viewWillDisappear
            .drive(onNext: { [weak self] in
                self?.navigationController?.setNavigationBarHidden(false, animated: false)
                self?.navigationController?.toolbar.isHidden = true
                self?.navigationController?.setToolbarHidden(true, animated: false)
            })
            .disposed(by: disposeBag)

        output
            .headerInfo
            .drive(onNext: { [weak self] (postItem, userInfo) in
                self?.embedPostHeaderViewController(postItem: postItem, userInfo: userInfo)
                self?.navigationItem.title = postItem.title
            })
            .disposed(by: disposeBag)

        output
            .footerInfo
            .drive(onNext: { [weak self] (uri, postItem) in
                self?.makePostFooterViewController(uri: uri, postItem: postItem)
            })
            .disposed(by: disposeBag)

        output
            .prevNextLink
            .drive(onNext: { [weak self] postLinkItem in
                self?.setLinkButton(button: self?.prevPostButton, postItem: postLinkItem.previousPost)
                self?.setLinkButton(button: self?.nextPostButton, postItem: postLinkItem.nextPost)
            })
            .disposed(by: disposeBag)

        output
            .showPostContent
            .drive(onNext: { [weak self] contentItem in
                self?.postWebView.loadHTMLString(contentItem, baseURL: nil)
            })
            .disposed(by: disposeBag)

        output
            .reloadPost
            .drive(onNext: { [weak self] _ in
                guard let `self` = self else { return }
                self.subscriptionView.isHidden = true
                self.postWebView.scrollView.isScrollEnabled = true
                self.removeHeaderFooter()
                self.postWebView.loadHTMLString("", baseURL: nil)
                self.showFullScreen(false)
            })
            .disposed(by: disposeBag)

        output
            .showNeedSubscription
            .drive(onNext: { [weak self] (userInfo, postInfo, _) in
                guard let `self` = self else { return }
                var buttonTitle: String {
                    if (postInfo.fanPass?.level ?? 0) == 0 {
                        return LocalizedStrings.btn_subs_free.localized()
                    }
                    return LocalizedStrings.btn_subs.localized()
                }
                var description: String {
                    return (postInfo.fanPass?.level ?? 0) == 0 ? LocalizedStrings.str_subs_only.localized() : LocalizedStrings.str_subs_only_with_fanpass.localized(with: postInfo.fanPass?.name ?? "")
                }
                self.subscriptionButton.setTitle(buttonTitle, for: .normal)
                self.subscriptionDescriptionLabel.text = description
                self.subscriptionView.isHidden = false
                self.postWebView.scrollView.isScrollEnabled = false

                for subview in self.postWebView.scrollView.subviews {
                    if subview.tag == 1001 {
                        subview.isHidden = true
                    }
                }
            })
            .disposed(by: disposeBag)

        output
            .hideNeedSubscription
            .drive(onNext: { [weak self] _ in
                self?.subscriptionView.isHidden = true
                self?.postWebView.scrollView.isScrollEnabled = true
            })
            .disposed(by: disposeBag)

        output
            .changeReadmode
            .drive(onNext: { [weak self] in
                self?.changeReadmode()
            })
            .disposed(by: disposeBag)

        output
            .openSignInViewController
            .drive(onNext: { [weak self] in
                self?.openSignInViewController()
            })
            .disposed(by: disposeBag)

        output
            .openFanPassListViewController
            .drive(onNext: { [weak self] (uri, postId) in
                self?.openFanPassListViewController(uri: uri, postId: postId)
            })
            .disposed(by: disposeBag)

        output
            .sharePost
            .drive(onNext: { [weak self] url in
                guard let `self` = self else { return }
                let activityViewController = UIActivityViewController(activityItems: [url], applicationActivities: [])

                activityViewController.excludedActivityTypes = [
                    UIActivity.ActivityType.print,
                    UIActivity.ActivityType.assignToContact,
                    UIActivity.ActivityType.saveToCameraRoll,
                    UIActivity.ActivityType.addToReadingList,
                    UIActivity.ActivityType.postToFlickr,
                    UIActivity.ActivityType.postToVimeo,
                    UIActivity.ActivityType.openInIBooks
                ]

                if let topController = UIApplication.topViewController() {
                    if UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiom.pad {
                        activityViewController.modalPresentationStyle = .popover
                        if let popover = activityViewController.popoverPresentationController {
                            popover.permittedArrowDirections = .up
                            popover.sourceView = topController.view
                            popover.sourceRect = CGRect(x: self.view.frame.size.width, y: 64, width: 0, height: 0)
                        }
                    }
                    topController.present(activityViewController, animated: true, completion: nil)
                }
            })
            .disposed(by: disposeBag)

        output
            .willBeginDecelerating
            .drive(onNext: { [weak self] in
                self?.showFullScreen()
            })
            .disposed(by: disposeBag)

        output
            .contentOffset
            .distinctUntilChanged()
            .drive(onNext: { [weak self] offset in
                guard let `self` = self else { return }
                let isScrollTop = offset.y <= -44
                let isScrollBottom = (offset.y + self.view.frame.size.height) >= self.postWebView.scrollView.contentSize.height
                if isScrollTop || isScrollBottom {
                    self.showFullScreen(false)
                }
            })
            .disposed(by: disposeBag)

        output
            .activityIndicator
            .drive(onNext: { status in
                Toast.loadingActivity(status)
            })
            .disposed(by: disposeBag)

        output
            .showToast
            .drive(onNext: { message in
                Toast.showToast(message)
            })
            .disposed(by: disposeBag)

        output
            .sharePost
            .drive(onNext: { url in

            })
            .disposed(by: disposeBag)

        view.rx.tapGesture(configuration: { gestureRecognizer, delegate in
                gestureRecognizer.delegate = self
                gestureRecognizer.cancelsTouchesInView = false
            })
            .when(.recognized)
            .subscribe(onNext: { [weak self] _ in
                self?.showFullScreen(!(self?.navigationController?.isNavigationBarHidden ?? false))
            })
            .disposed(by: disposeBag)
    }
}

extension PostViewController: WKNavigationDelegate {
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        if #available(iOS 13.0, *) {
            setWebviewColor()
        }
        webView.evaluateJavaScript("document.readyState") { (complete, error) in
            if complete != nil {
                webView.evaluateJavaScript("document.body.scrollHeight", completionHandler: { (height, error) in
                    guard
                        self.subscriptionView.isHidden,
                        let height = height as? CGFloat
                    else { return }
                    self.embedPostFooterViewController(height: height)
                })
            }
        }
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        if navigationAction.navigationType == .linkActivated  {
            guard
                let requestUrlString = navigationAction.request.url?.absoluteString,
                let url = URL(string: requestUrlString)
            else {
                decisionHandler(.allow)
                return
            }
            if requestUrlString.contains("http://") || requestUrlString.contains("https://") {
                let safariViewController = SFSafariViewController(url: url)
                present(safariViewController, animated: true, completion: nil)
            } else {
                UIApplication.shared.open(url)
            }
            decisionHandler(.cancel)
        } else {
            decisionHandler(.allow)
        }
    }
}

extension PostViewController: UIScrollViewDelegate {
    func scrollViewWillBeginZooming(_ scrollView: UIScrollView, with view: UIView?) {
        scrollView.pinchGestureRecognizer?.isEnabled = false
    }
}

extension PostViewController: PostFooterViewDelegate {
    func loadComplete() {
        guard
            let footerViewController = self.footerViewController,
            let contentHeight = footerViewController.tableView?.contentSize.height
        else { return }
        postWebView.evaluateJavaScript("document.body.style.marginBottom =\"\(contentHeight)px\"")
    }
    func reloadPost(postId: Int) {
        loadPost.onNext(postId)
    }
}

extension PostViewController: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        if (touch.view?.isKind(of: UIControl.self) ?? false) {
            return false
        }
        return true
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        if gestureRecognizer.isKind(of: UITapGestureRecognizer.self)
            && otherGestureRecognizer.isKind(of: UIPanGestureRecognizer.self) {
            return false
        }
        return true
    }
}

extension PostViewController {
    private func setLinkButton(button: UIButton?, postItem: PostModel?) {
        let isEnabled = postItem?.id != nil
        button?.isEnabled = isEnabled
        var buttonColor: UIColor {
            if #available(iOS 13.0, *) {
                return isEnabled ? .pictionDarkGrayDM : UIColor(r: 151, g: 151, b: 151)
            } else {
                return isEnabled ? UIColor(r: 51, g: 51, b: 51) : UIColor(r: 151, g: 151, b: 151)
            }
        }
        button?.setTitleColor(buttonColor, for: .normal)
    }
}
