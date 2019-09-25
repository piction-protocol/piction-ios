//
//  ImagePickerManager.swift
//  PictionView
//
//  Created by jhseo on 20/06/2019.
//  Copyright © 2019 Piction Network. All rights reserved.
//

import UIKit
import RxSwift
import RxCocoa
//
//protocol ImagePickerManagerProtocol {
//    var imageId: String { get }
//}
//
//final class ImagePickerManager: ImagePickerManagerProtocol {
//    var imageId: String
//
//    init() {
//        let imagePicker = UIImagePickerController()
//        imagePicker.delegate = self
//        imagePicker.allowsEditing = false
//        imagePicker.sourceType = UIImagePickerController.SourceType.photoLibrary
//    }
//}
//
//extension ImagePickerManager: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
//    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
//        dismiss(animated: true, completion: nil)
//    }
//
//    internal func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
//
//        if let chosenImage = info[UIImagePickerController.InfoKey.originalImage] as? UIImage {
//            dismiss(animated: true) { [weak self] in
//                self?.selectedImage = chosenImage
//            }
//        }
//    }
//}
