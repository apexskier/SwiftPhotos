//
//  Tasks.swift
//  SwiftPhotos
//
//  Created by Cameron Little on 12/10/14.
//  Copyright (c) 2014 Cameron Little. All rights reserved.
//

import Cocoa
import CoreData
import Dispatch
import Foundation

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

    func cancelPhoto(path: String) {
        if let task = pendingDiscoveries.inProgress.removeValueForKey(path) {
            task.cancel()
        }
        if let task = pendingHashes.inProgress.removeValueForKey(path) {
            task.cancel()
        }
        if let task = pendingQuality.inProgress.removeValueForKey(path) {
            task.cancel()
        }
    }

    func photoTask(photo: Photo, queue: OperationQueue, optype: String, then: () -> ()) {
        let path = photo.filepath
        let id = photo.objectID

        if let currentOperation = queue.inProgress[path] {
            return
        }

        var op: NSOperation
        switch optype {
        case "PhotoDiscoverer":
            op = PhotoDiscoverer(photoID: id, qos: .Utility)
        case "PhotoHasher":
            op = PhotoHasher(photoID: id, qos: .Background)
        case "PhotoQualityGenerator":
            op = PhotoQualityGenerator(photoID: id, qos: .Background)
        default:
            fatalError("Unknown operation type: \(optype)")
        }
        op.completionBlock = {
            if op.cancelled {
                return
            }
            dispatch_async(dispatch_get_main_queue(), {
                NSNotificationCenter.defaultCenter().postNotificationName("completedTask", object: nil)
                queue.inProgress.removeValueForKey(photo.filepath)
                then()
                return
            })
        }

        queue.inProgress[path] = op
        queue.queue.addOperation(op)
    }

    func discoverPhoto(photo: Photo) {
        photoTask(photo, queue: pendingDiscoveries, optype: "PhotoDiscoverer") {
            if photo.stateEnum == .Broken {
                return
            }
            self.hashPhoto(photo)
            //self.qualityPhoto(photo)
        }
    }

    func hashPhoto(photo: Photo) {
        if photo.stateEnum == .New {
            photoTask(photo, queue: pendingHashes, optype: "PhotoHasher") {}
        }
    }

    func qualityPhoto(photo: Photo) {
        photoTask(photo, queue: pendingQuality, optype: "PhotoQualityGenerator") {}
    }
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

class PhotoOperation: NSOperation {
    let photoID: NSManagedObjectID

    init(photoID: NSManagedObjectID, qos: NSQualityOfService) {
        self.photoID = photoID
        super.init()
        self.qualityOfService = qos//.Background
        self.queuePriority = .Low
    }
}

class PhotoHasher: PhotoOperation {
    override func main() {
        autoreleasepool {
            if self.cancelled {
                return
            }
            let moc = NSManagedObjectContext(concurrencyType: .MainQueueConcurrencyType)
            moc.persistentStoreCoordinator = CoreDataStackManager.sharedManager.persistentStoreCoordinator
            var error: NSError?

            if let photo = moc.objectWithID(self.photoID) as? Photo {
                photo.genFhash()
                // photo.genPhash()
                photo.genAhash()

                let appDelegate = NSApplication.sharedApplication().delegate as AppDelegate
                let dups = appDelegate.bkTree.find(photo.objectID, n: 0, moc: moc)
                if dups.count > 0 {
                    for p in dups {
                        let ph = moc.objectWithID(p) as Photo
                        let duplicates = photo.mutableSetValueForKey("duplicates")
                        if !duplicates.containsObject(ph) {
                            duplicates.addObject(ph)
                        }
                    }
                }
                appDelegate.bkTree.insert(photo.objectID, moc: moc)

                photo.stateEnum = .Known

                if !moc.save(&error) {
                    println("Coudn't save moc: \(error)")
                }
            } else {
                println("missing photo \(self.photoID)")
            }
        }
    }
}

class PhotoDiscoverer: PhotoOperation {
    override func main() {
        autoreleasepool {
            if self.cancelled {
                return
            }
            let moc = NSManagedObjectContext(concurrencyType: .MainQueueConcurrencyType)
            moc.persistentStoreCoordinator = CoreDataStackManager.sharedManager.persistentStoreCoordinator
            var error: NSError?

            if let photo = moc.objectWithID(self.photoID) as? Photo {
                photo.readData()
                if !moc.save(&error) {
                    println("Coudn't save moc: \(error)")
                }
            } else {
                println("missing photo \(self.photoID)")
            }
        }
    }
}

class PhotoQualityGenerator: PhotoOperation {
    override func main() {
        autoreleasepool {
            if self.cancelled {
                return
            }
            let moc = NSManagedObjectContext(concurrencyType: .MainQueueConcurrencyType)
            moc.persistentStoreCoordinator = CoreDataStackManager.sharedManager.persistentStoreCoordinator
            var error: NSError?

            if let photo = moc.objectWithID(self.photoID) as? Photo {
                photo.genQualityMeasures()
                if !moc.save(&error) {
                    println("Coudn't save moc: \(error)")
                }
            } else {
                println("missing photo \(self.photoID)")
            }
        }
    }
}