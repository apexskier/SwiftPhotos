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

    var pendingDiscoveries = OperationQueue("discoveryQueue", qualityOfService: .Utility)
    var pendingHashes =  OperationQueue("hashQueue", qualityOfService: .Background)
    var pendingQuality =  OperationQueue("qualityQueue", qualityOfService: .Background)
}

// http://www.raywenderlich.com/76341/use-nsoperation-nsoperationqueue-swift
class OperationQueue {
    var name: String
    var qualityOfService: NSQualityOfService
    lazy var inProgress = [String:NSOperation]()
    lazy var queue: NSOperationQueue = {
        var q = NSOperationQueue()
        q.name = self.name
        q.maxConcurrentOperationCount = 1
        q.qualityOfService = self.qualityOfService
        //q.suspended = true
        return q
    }()
    init(_ name: String, qualityOfService: NSQualityOfService) {
        self.name = name
        self.qualityOfService = qualityOfService
    }
}

class PhotoHasher: NSOperation {
    let photo: Photo
    
    init(photo: Photo) {
        self.photo = photo
        super.init()
        self.qualityOfService = .Background
        self.queuePriority = .Low
    }
    
    override func main() {
        autoreleasepool {
            if self.cancelled {
                return
            }
            
            self.photo.genFhash()
            self.photo.genPhash()
        }
    }
}

class PhotoDiscoverer: NSOperation {
    let photo: Photo
    
    init(photo: Photo) {
        self.photo = photo
        super.init()
        self.qualityOfService = .Utility
        self.queuePriority = .Low
    }
    
    override func main() {
        autoreleasepool {
            if self.cancelled {
                return
            }
            
            self.photo.readData()
        }
    }
}

class PhotoQualityGenerator: NSOperation {
    let photo: Photo
    
    init(photo: Photo) {
        self.photo = photo
        super.init()
        self.qualityOfService = .Background
        self.queuePriority = .Low
    }
    
    override func main() {
        autoreleasepool {
            if self.cancelled {
                return
            }
            
            self.photo.genQualityMeasures()
        }
    }
}