//
//  Extensions.swift
//  GameOfChat
//
//  Created by SEAN on 2017/9/24.
//  Copyright © 2017年 SEAN. All rights reserved.
//

import UIKit

extension UIColor {
    
    convenience init(r: CGFloat, g: CGFloat, b: CGFloat) {
        self.init(red: r/255, green: g/255, blue: b/255, alpha: 1)
    }
}


let imageCache = NSCache<AnyObject, AnyObject>()

class CustomImageView: UIImageView {
    
    var imageUrlString: String?
    
    func loadImageUsingCacheWithUrlString(_ urlString: String) {
        
        imageUrlString = urlString
        
        image = nil
        
        
        //check cache for image first
        if let cachedImage = imageCache.object(forKey: urlString as AnyObject) as? UIImage{
            self.image = cachedImage
            return
        }
        
        let url = URL(string: urlString)
        URLSession.shared.dataTask(with: url!, completionHandler: { (data, response, error) in
            
            if error != nil {
                print(error ?? "profileImageUrl error")
                return
            }
            
            DispatchQueue.main.async ( execute : {
                
                if let downloadImage = UIImage(data: data!){
                    
                    imageCache.setObject(downloadImage, forKey: urlString as AnyObject)
                    
                    if self.imageUrlString == urlString{
                    self.image = downloadImage
                    }
                }     
                
            })
            
        }).resume()
    }

}


