//
//  Tasks.swift
//  SwiftPhotos
//
//  Created by Cameron Little on 12/10/14.
//  Copyright (c) 2014 Cameron Little. All rights reserved.
//

import Foundation
import Dispatch

class TaskManager {
    
    private struct Constants {
    }
    
    class var sharedManager: CoreDataStackManager {
        struct Singleton {
            static let taskManager = CoreDataStackManager()
        }
        
        return Singleton.taskManager
    }

}

// http://www.raywenderlich.com/76341/use-nsoperation-nsoperationqueue-swift
class PhotoOperations {
    lazy var hashesInProgress = [String:NSOperation]()
    lazy var hashesQueue: NSOperationQueue = {
        var q = NSOperationQueue()
        q.name = "Hashes Queue"
        q.maxConcurrentOperationCount = 1 // TODO: remove this line
        return q
    }()
}

class PhotoHasher: NSOperation {
    let photo: Photo
    
    init(photo: Photo) {
        self.photo = photo
    }
    
    override func main() {
        autoreleasepool {
            println("Started hashing \(self.photo.filepath)")
            if self.cancelled {
                println("Cancelled hashing \(self.photo.filepath)")
                return
            }
            
            self.photo.genPhash()
            self.photo.stateEnum = .Known
            println("Done phashing \(self.photo.filepath)")
        }
    }
}

class PhotoDiscoverer: NSOperation {
    let photo: Photo
    
    init(photo: Photo) {
        self.photo = photo
    }
    
    override func main() {
        autoreleasepool {
            if self.cancelled {
                return
            }
            
            self.photo.genFhash()
            self.photo.readData()
            self.photo.stateEnum = .Known
            
            //self.photo.save()
        }
    }
}