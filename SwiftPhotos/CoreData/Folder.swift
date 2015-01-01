//
//  CoreData.swift
//  SwiftPhotos
//
//  Created by Cameron Little on 11/25/14.
//  Copyright (c) 2014 Cameron Little. All rights reserved.
//

import Foundation
import CoreData

class Folder: NSManagedObject {

    @NSManaged var path: String
    
    var url: NSURL? {
        get {
            return NSURL(string: path)
        }
        set(newURL) {
            if let url = newURL {
                path = url.absoluteString!
            }
        }
    }

}
