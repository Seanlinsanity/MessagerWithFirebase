//
//  Message.swift
//  GameOfChat
//
//  Created by SEAN on 2017/9/25.
//  Copyright © 2017年 SEAN. All rights reserved.
//

import UIKit
import Firebase

class Message: NSObject {
    
    var fromId: String?
    var toId: String?
    var timeStamp: NSNumber?
    var text: String?
    var videoUrl: String?
    
    var imageUrl: String?
    var imageWidth: NSNumber?
    var imageHeight: NSNumber?
    
    func chatPartnerId() -> String?{
        
        return fromId == Auth.auth().currentUser?.uid ? toId: fromId
    }
    
    init(dictionay: [String: AnyObject]) {
        super.init()

        fromId = dictionay["fromId"] as? String
        text = dictionay["text"] as? String
        toId = dictionay["toId"] as? String
        imageUrl = dictionay["imageUrl"] as? String
        videoUrl = dictionay["videoUrl"] as? String

        timeStamp = dictionay["timeStamp"] as? NSNumber
        imageWidth = dictionay["imageWidth"] as? NSNumber
        imageHeight = dictionay["imageHeight"] as? NSNumber


    }
    
}
