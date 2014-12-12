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
    
    class var sharedManager: TaskManager {
        struct Singleton {
            static let taskManager = TaskManager()
        }
        
        return Singleton.taskManager
    }

    var pendingDiscoveries = PhotoOperations("discoveryQueue")
    var pendingHashes = PhotoOperations("hashQueue")
}

// http://www.raywenderlich.com/76341/use-nsoperation-nsoperationqueue-swift
class PhotoOperations {
    var name: String
    lazy var inProgress = [String:NSOperation]()
    lazy var queue: NSOperationQueue = {
        var q = NSOperationQueue()
        q.name = self.name
        q.maxConcurrentOperationCount = 1 // TODO: remove this line
        return q
    }()
    init(_ name: String) {
        self.name = name
    }
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
            println("Started discovering \(self.photo.filepath)")
            if self.cancelled {
                return
            }
            
            self.photo.genFhash()
            self.photo.readData()
        }
    }
}