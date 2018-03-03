//
//  LoginController+handlers.swift
//  GameOfChat
//
//  Created by SEAN on 2017/9/23.
//  Copyright © 2017年 SEAN. All rights reserved.
//

import UIKit
import Firebase

extension LoginController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    
  
    func handleRegister() {
        
        guard let email = emailTextField.text, let password = passwordTextField.text, let name = nameTextField.text else {
            print("Form is not valid")
            return
        }
        
        Auth.auth().createUser(withEmail: email, password: password) { (user: User?, error) in
            
            if error != nil {
                print(error ?? "error")
                return
            }
            
            guard let uid = user?.uid else {
                return
            }
            
            //successfully authenticated user
            let imageName = NSUUID().uuidString
            let storageRef = Storage.storage().reference().child("profile_images").child("\(imageName).jpg")
            
            if let profileImage = self.profileImageView.image {
                
         
            if let uploadData = UIImageJPEGRepresentation(profileImage, 0.1) {
            
//            if let uploadData = UIImagePNGRepresentation(self.profileImageView.image!){
                
                storageRef.putData(uploadData, metadata: nil, completion: { (metadata, error) in
                    
                    if error != nil {
                        print(error ?? "error")
                        return
                    }
                    
                    
                    if let profileImageUrl = metadata?.downloadURL()?.absoluteString {
                    
                        let values = ["name": name, "email": email, "profileImageUrl": profileImageUrl]
                    
                        self.registerUserIntoDatabaseWithUID(uid, values: values as [String : AnyObject])
                    
                        //print(metadata ?? "no metadata")
                        
                        }
                    })
                }
            }
        }
    }
    
    fileprivate func registerUserIntoDatabaseWithUID(_ uid: String, values: [String: AnyObject]) {
    
        let ref = Database.database().reference()
        let userReference = ref.child("user").child(uid)
        userReference.updateChildValues(values, withCompletionBlock: { (err, ref) in
            
            if err != nil {
                print(err ?? "err")
                return
            }
            
            //print("Save user sucessfully into Firebase db")
            
            let user = UserInfo()
            user.setValuesForKeys(values)
            self.messageController?.setupNavBarWithUser(user: user)
            self.messageController?.navigationItem.title = values["name"] as? String
            self.dismiss(animated: true, completion: nil)
        
        })
    }
    
    
    @objc func handleSelectProfileImage() {
        
        let picker = UIImagePickerController()
        
        picker.delegate = self
        picker.allowsEditing = true
            
        present(picker, animated: true, completion: nil)
        
    }
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]) {
        
        var seletedImageFromPicker : UIImage?
        
        if let editedImage = info["UIImagePickerControllerEditedImage"] as? UIImage{
            seletedImageFromPicker = editedImage
        }
        
        else if let  originalImage = info["UIImagePickerControllerOriginalImage"] as? UIImage{
            seletedImageFromPicker = originalImage
        }
        
        if let selectedImage = seletedImageFromPicker {
            profileImageView.image = selectedImage
        }
        
        dismiss(animated: true, completion: nil)
        
    }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        
        dismiss(animated: true, completion: nil)
        
    }
    
}
