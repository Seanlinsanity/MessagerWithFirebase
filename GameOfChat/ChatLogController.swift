//
//  ChatLogController.swift
//  GameOfChat
//
//  Created by SEAN on 2017/9/25.
//  Copyright © 2017年 SEAN. All rights reserved.
//

import UIKit
import Firebase
import MobileCoreServices
import AVFoundation

class ChatLogController: UICollectionViewController, UITextFieldDelegate, UICollectionViewDelegateFlowLayout, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        collectionView?.collectionViewLayout.invalidateLayout()
    }
    
    var user: UserInfo? {
        
        didSet{
            navigationItem.title = user?.name
            observeMessages()
        }
        
    }
    
    var messages = [Message]()
    
    func observeMessages(){
        guard let uid = Auth.auth().currentUser?.uid, let toId = user?.id else {
            return
        }
        let userMessagesRef = Database.database().reference().child("user-messages").child(uid).child(toId)
        userMessagesRef.observe(.childAdded, with: { (snapshot) in
            //print(snapshot)
            
            let messageId = snapshot.key
            let messagesRef = Database.database().reference().child("messages").child(messageId)
            messagesRef.observeSingleEvent(of: .value, with: { (snapshot) in
                
                guard let dictionary = snapshot.value as? [String: AnyObject] else{
                    return
                }
                let message = Message(dictionay: dictionary)
//                maybe crash using append function here
//                self.messages.append(message)
                
                    DispatchQueue.main.async {
                        self.messages.append(message)
                        self.collectionView?.reloadData()
                        //scroll to the last index
                        if self.messages.count > 0{
                            let indexPath = NSIndexPath(item: self.messages.count - 1, section: 0)
                            self.collectionView?.scrollToItem(at: indexPath as IndexPath, at: .bottom, animated: true)
                        }
                    }
                
            }, withCancel: nil)
        
        }, withCancel: nil)
    }
    
    let cellId = "cellId"
    
    override func viewDidLoad() {
        super.viewDidLoad()

        collectionView?.contentInset = UIEdgeInsets(top: 8, left: 0, bottom: 8, right: 0)
        collectionView?.alwaysBounceVertical = true
        collectionView?.backgroundColor = .white
        collectionView?.register(ChatMessageCell.self, forCellWithReuseIdentifier: cellId)
        
        collectionView?.keyboardDismissMode = .interactive
       
        setupKeyboardObservers()
    }
    
    lazy var inputContainerView : ChatInputContainerView = {
        
        let chatInputContainerView = ChatInputContainerView(frame: CGRect(x: 0, y: 0, width: self.view.frame.width, height: 50))
        chatInputContainerView.chatLogController = self
        return chatInputContainerView
        
    }()
    
    @objc func handleUploadTap() {
        let imagePickerController = UIImagePickerController()
        
        imagePickerController.delegate = self
        imagePickerController.allowsEditing = true
        
        imagePickerController.mediaTypes = [kUTTypeImage as String, kUTTypeMovie as String]
        
        present(imagePickerController, animated: true, completion: nil)
        
    }
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]) {
        
        if let videoUrl = info[UIImagePickerControllerMediaURL] as? URL{
            handleVideoSelectedForUrl(url: videoUrl)
            
        } else {
            
            handleImageSelectedForInfo(info: info as [String : AnyObject])
        }
        
        dismiss(animated: true, completion: nil)
    }
    
    private func handleVideoSelectedForUrl(url: URL){
        
        let filename = NSUUID().uuidString + ".mov"
        let uploadTask = Storage.storage().reference().child("message-movies").child(filename).putFile(from: url, metadata: nil, completion: { (metadata, error) in
            
            if error != nil{
                print(error ?? "error uploading video")
                return
            }
            
            if let videoUrl = metadata?.downloadURL()?.absoluteString{
                //print(storageUrl)
                if let thumbnailImage = self.thumbnailImageForFileUrl(fileUrl: url) {
             
                    self.uploadToFirebaseStorageUsingImage(image: thumbnailImage, completion: { (imageUrl) in
                        
                        let properties = ["imageUrl": imageUrl, "imageWidth": thumbnailImage.size.width, "imageHeight": thumbnailImage.size.height, "videoUrl": videoUrl] as [String : AnyObject]
                        
                        //print(properties)
                        
                        self.sendMessageWithProperties(properties: properties)
                    })
                }
            }
        })
        
        uploadTask.observe(.progress) { (snapshot) in
            if let completedUnitCount = snapshot.progress?.completedUnitCount, let totalUnitCount = snapshot.progress?.totalUnitCount {
                
                let uploadPercentage: Float64 = Float64(completedUnitCount) * 100 / Float64(totalUnitCount)
                
                self.navigationItem.title = String(format: "%.0f", uploadPercentage) + "%"
            
            }
        }
        
        uploadTask.observe(.success) { (snapshot) in
            
                self.navigationItem.title = self.user?.name
    
        }
        
    }
    
    private func thumbnailImageForFileUrl(fileUrl: URL) -> UIImage? {
        let asset = AVAsset(url: fileUrl)
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        
        do {
            let thumbnailImage = try imageGenerator.copyCGImage(at: CMTimeMake(1, 60), actualTime: nil)
            return UIImage(cgImage: thumbnailImage)
            
        } catch let err {
            print(err)
        }
        
        return nil
    }
    
    private func handleImageSelectedForInfo(info: [String: AnyObject]) {
        var seletedImageFromPicker : UIImage?
        
        if let editedImage = info["UIImagePickerControllerEditedImage"] as? UIImage{
            seletedImageFromPicker = editedImage
        }
            
        else if let  originalImage = info["UIImagePickerControllerOriginalImage"] as? UIImage{
            seletedImageFromPicker = originalImage
        }
        
        if let selectedImage = seletedImageFromPicker {
            uploadToFirebaseStorageUsingImage(image: selectedImage, completion: { (imageUrl) in
                self.sendMessageWithImageUrl(imageUrl: imageUrl, image: selectedImage)
            })
        }
        
    }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        dismiss(animated: true, completion: nil)
        
    }
    
    private func uploadToFirebaseStorageUsingImage(image: UIImage, completion: @escaping (_ imageUrl: String) -> ()){
        
        let imageName = NSUUID().uuidString
        let ref = Storage.storage().reference().child("message_images").child(imageName)
        
        if let uploadData = UIImageJPEGRepresentation(image, 0.2){
            ref.putData(uploadData, metadata: nil, completion: { (metadata, error) in
                
                if error != nil{
                    print(error ?? "upload Image error")
                }
                
                //print(metadata!.downloadURL()!.absoluteString)
                if let imageUrl = metadata?.downloadURL()?.absoluteString{
                    completion(imageUrl)
                    
                }
            })
        }
    }
    
    override var inputAccessoryView: UIView?{
        
        get{
            return inputContainerView
        }
    }
    
    override var canBecomeFirstResponder: Bool {
        return true
    }
    
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        NotificationCenter.default.removeObserver(self)
    }
    
    func setupKeyboardObservers() {
        
        NotificationCenter.default.addObserver(self, selector: #selector(handleKeyboardDidShow), name: NSNotification.Name.UIKeyboardDidShow, object: nil)
        
//        NotificationCenter.default.addObserver(self, selector: #selector(handleKeyboardWillShow), name: NSNotification.Name.UIKeyboardWillShow, object: nil)
//        
//        NotificationCenter.default.addObserver(self, selector: #selector(handleKeyboardWillHide), name: NSNotification.Name.UIKeyboardWillHide, object: nil)
    }
    
    @objc func handleKeyboardDidShow() {
        if messages.count > 0 {
        let indexPath = NSIndexPath(item: messages.count - 1, section: 0)
        collectionView?.scrollToItem(at: indexPath as IndexPath, at: .top, animated: true)
        }
    }
//    
//    func handleKeyboardWillShow(notification: Notification){
//        let keyboardFrame = (notification.userInfo?[UIKeyboardFrameEndUserInfoKey] as AnyObject).cgRectValue
//        let keyboardDuration = (notification.userInfo?[UIKeyboardAnimationDurationUserInfoKey] as AnyObject).doubleValue
//        
//        containerViewBottomAnchor?.constant = -keyboardFrame!.height
//        UIView.animate(withDuration: keyboardDuration!) {
//            self.view.layoutIfNeeded()
//        }
//    }
//    
//    func handleKeyboardWillHide(notification: Notification) {
//        let keyboardDuration = (notification.userInfo?[UIKeyboardAnimationDurationUserInfoKey] as AnyObject).doubleValue
//        
//        containerViewBottomAnchor?.constant = 0
//        UIView.animate(withDuration: keyboardDuration!) {
//            self.view.layoutIfNeeded()
//        }
//    }
    
    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return messages.count
    }
    
    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: cellId, for: indexPath) as! ChatMessageCell
        
        cell.chatLogController = self
        
        let message = messages[indexPath.item]
        
        cell.message = message
        
        cell.textView.text = message.text
        
        setupCell(cell: cell, message: message)
        
        if let text = message.text{
            cell.textView.isHidden = false
            cell.bubbleWidthAnchor?.constant = estimateFrameForText(text: text).width + 32
        
        } else if message.imageUrl != nil {
            cell.textView.isHidden = true
            cell.bubbleWidthAnchor?.constant = 200
            
        }
        
        cell.playButton.isHidden = message.videoUrl == nil
        
        return cell
    }
    
    private func setupCell(cell: ChatMessageCell, message: Message) {

        
        if let profileImageUrl = self.user?.profileImageUrl{

            cell.profileImageView.loadImageUsingCacheWithUrlString(profileImageUrl)
        
        }
        
        if message.fromId == Auth.auth().currentUser?.uid {
            cell.bubbleView.backgroundColor = ChatMessageCell.blueColor
            cell.textView.textColor = .white
            cell.profileImageView.isHidden = true
            cell.bubbleViewRightAnchor?.isActive = true
            cell.bubbleViewLeftAnchor?.isActive = false
        
        }else{
            
            cell.bubbleView.backgroundColor = UIColor(r: 240, g: 240, b: 240)
            cell.textView.textColor = .black
            cell.profileImageView.isHidden = false
            cell.bubbleViewRightAnchor?.isActive = false
            cell.bubbleViewLeftAnchor?.isActive = true
        }
        
        if let messageImageUrl = message.imageUrl {
            cell.messageImageView.isHidden = false
            cell.bubbleView.backgroundColor = .clear
            cell.messageImageView.loadImageUsingCacheWithUrlString(messageImageUrl)
        }else {
            cell.messageImageView.isHidden = true
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        
        var height: CGFloat = 80
        
        let message = messages[indexPath.item]
        if let text = message.text {
            height = estimateFrameForText(text: text).height + 20
        
        }else if let imageWidth = message.imageWidth?.floatValue, let imageHeight = message.imageHeight?.floatValue {
            
            height = CGFloat(imageHeight / imageWidth * 200)

        }
        
        let width = UIScreen.main.bounds.width
        
        return CGSize(width: width, height: height)
    }
    
    private func estimateFrameForText(text: String) -> CGRect {
        
        let size = CGSize(width: 200, height: 1000)  //height is just an large arbitary
        
        let options = NSStringDrawingOptions.usesFontLeading.union(.usesLineFragmentOrigin)
        
        return NSString(string: text).boundingRect(with: size, options: options, attributes: [NSAttributedStringKey.font : UIFont.systemFont(ofSize: 16)], context: nil)
        
    }
    
    var containerViewBottomAnchor: NSLayoutConstraint?
    
    @objc func handleSend() {
        
        let properties = ["text": inputContainerView.inputTextField.text!] as [String : AnyObject]
        
            sendMessageWithProperties(properties: properties)
    }
    
    private func sendMessageWithImageUrl(imageUrl: String, image: UIImage){
        
        let properties = ["imageUrl": imageUrl, "imageWidth": image.size.width, "imageHeight": image.size.height] as [String : AnyObject]
        
            sendMessageWithProperties(properties: properties)
    }
    
    private func sendMessageWithProperties(properties: [String: AnyObject]){
        
        let ref = Database.database().reference().child("messages")
        let childRef = ref.childByAutoId()
        let toId = user!.id!
        let fromId = Auth.auth().currentUser!.uid
        let timeStamp = Int(Date().timeIntervalSince1970)
        
        var values = ["toId": toId, "fromId": fromId, "timeStamp": timeStamp] as [String : AnyObject]
        
        //key $0, value $1
        properties.forEach({values[$0] = $1})
        
        childRef.updateChildValues(values) { (error, ref) in
            if error != nil {
                print(error ?? "send message error")
            }
            
            self.inputContainerView.inputTextField.text = nil
            
            let userMessagesRef = Database.database().reference().child("user-messages").child(fromId).child(toId)
            
            let messageId = childRef.key
            
            userMessagesRef.updateChildValues([messageId: 1])
            
            let recipientUserMessagesRef = Database.database().reference().child("user-messages").child(toId).child(fromId)
            
            recipientUserMessagesRef.updateChildValues([messageId: 1])
        }

        
    }

    
    
    var startingFrame: CGRect?
    var blackBackgroundView: UIView?
    var startingImageView : UIImageView?
    var zoomingImageView: UIImageView?
    
    //my custom zooming logic
    func performZoomInForStartingImageView(startingImageView: UIImageView) {
        
        self.startingImageView = startingImageView
        self.startingImageView?.isHidden = true
        
        startingFrame = startingImageView.superview?.convert(startingImageView.frame, to: nil)
        zoomingImageView = UIImageView(frame: startingFrame!)
        
        self.zoomingImageView?.image = startingImageView.image
        self.zoomingImageView?.isUserInteractionEnabled = true
        
//        self.zoomingImageView?.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(handleZoomOut)))
        
        if let keyWindow = UIApplication.shared.keyWindow {
         
            blackBackgroundView = UIView(frame: keyWindow.frame)
            blackBackgroundView?.backgroundColor = .black
            blackBackgroundView?.alpha = 0
            
            keyWindow.addSubview(blackBackgroundView!)
            keyWindow.addSubview(self.zoomingImageView!)
            
            UIView.animate(withDuration: 0.4, delay: 0, usingSpringWithDamping: 1, initialSpringVelocity: 1, options: .curveEaseOut, animations: { 
                
                self.blackBackgroundView!.alpha = 1
                self.inputContainerView.alpha = 0
                
                
                
                let height = self.startingFrame!.height / self.startingFrame!.width * keyWindow.frame.width
                
                self.zoomingImageView?.frame = CGRect(x: 0, y: 0, width: keyWindow.frame.width, height: height)
                //self.zoomingImageView?.frame.size.width = keyWindow.frame.width
                //self.zoomingImageView?.frame.size.height = height
                self.zoomingImageView?.center = keyWindow.center
                
                self.blackBackgroundView?.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.handleZoomOut)))
                
                
            }, completion: nil)
            
        }
    }
    
//    func handleZoomOut(tapGesture: UITapGestureRecognizer){
//    
//        if let zoomOutImageVIew = tapGesture.view{
//            
//            zoomOutImageVIew.layer.cornerRadius = 16
//            zoomOutImageVIew.layer.masksToBounds = true
//            
//            UIView.animate(withDuration: 0.5, delay: 0, usingSpringWithDamping: 1, initialSpringVelocity: 1, options: .curveEaseOut, animations: { 
//                
//                zoomOutImageVIew.frame = self.startingFrame!
//                
//                self.blackBackgroundView?.alpha = 0
//                self.inputContainerView.alpha = 1
//                
//            }, completion: { (completion: Bool) in
//                
//                zoomOutImageVIew.removeFromSuperview()
//                self.startingImageView?.isHidden = false
//            })
//            
//        }
//    }
    
    @objc func handleZoomOut() {
        let zoomOutImageView = self.zoomingImageView
        
        zoomOutImageView?.layer.cornerRadius = 16
        zoomOutImageView?.layer.masksToBounds = true
        
        UIView.animate(withDuration: 0.5, delay: 0, usingSpringWithDamping: 1, initialSpringVelocity: 1, options: .curveEaseOut, animations: {
            
                            zoomOutImageView?.frame = self.startingFrame!
            
                            self.blackBackgroundView?.alpha = 0
                            self.inputContainerView.alpha = 1
            
                        }, completion: { (completion: Bool) in
            
                            zoomOutImageView?.removeFromSuperview()
                            self.startingImageView?.isHidden = false
                        })
                        
            }

    
    
}
