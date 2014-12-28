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
    
    class var sharedManager: TaskManager {
        struct Singleton {
            static let taskManager = TaskManager()
        }
        
        return Singleton.taskManager
    } 

    var queue: NSOperationQueue = {
        var q = NSOperationQueue()
        q.name = "com.camlittle.SwiftPhotos.Tasks"
        q.qualityOfService = .Utility
        q.maxConcurrentOperationCount = 1
        // q.suspended = true
        return q
    }()

    var operationsInProgress = [NSManagedObjectID: [String: NSBlockOperation]]()

    func cancelPhoto(id: NSManagedObjectID) {
        if let tasks = operationsInProgress.removeValueForKey(id) {
            for (type, task) in tasks {
                task.cancel()
            }
        }
    }

    func cancelTask(id: NSManagedObjectID, type: String) {
        if operationsInProgress[id] != nil {
            var tasks = operationsInProgress[id]!
            if let task = tasks.removeValueForKey(type) {
                task.cancel()
            }
        }
        if operationsInProgress[id]?.count == 0 {
            operationsInProgress.removeValueForKey(id)
        }
    }

    func pause() -> Bool {
        let prev = self.queue.suspended
        self.queue.suspended = true
        return prev
    }

    func resume() -> Bool {
        let prev = self.queue.suspended
        self.queue.suspended = false
        return prev
    }

    // by default this will *restart* tasks
    func startTask(id: NSManagedObjectID, type: String, operation: NSBlockOperation) {
        // cancel task if already started
        if let currentOperationContainer = operationsInProgress[id] {
            if let currentOperation = currentOperationContainer[type] {
                currentOperation.cancel()
            }
        }

        operation.completionBlock = {
            if operation.cancelled {
                return
            }
            dispatch_async(dispatch_get_main_queue(), {
                NSNotificationCenter.defaultCenter().postNotificationName("completedTask", object: nil)
                NSNotificationCenter.defaultCenter().postNotificationName("completedTask.\(type)", object: nil)
                self.cancelTask(id, type: type)
            })
        }

        if operationsInProgress[id] == nil {
            operationsInProgress[id] = [String: NSBlockOperation]()
        }
        operationsInProgress[id]![type] = operation
        queue.addOperation(operation)
    }

    private func startPhotoTask(photoID: NSManagedObjectID, type: String, priority: NSOperationQueuePriority, qualityOfService: NSQualityOfService, task: (photo: Photo, managedObjectContext: NSManagedObjectContext) -> Void) {
        let operation = NSBlockOperation(block: { () in
            let moc = createPrivateMOC()

            NSNotificationCenter.defaultCenter().addObserverForName(NSManagedObjectContextDidSaveNotification, object: nil, queue: nil, usingBlock: { (notification: NSNotification!) in
                if notification.object as NSManagedObjectContext != moc {
                    moc.performBlockAndWait({
                        moc.mergeChangesFromContextDidSaveNotification(notification)
                    })
                }
            })

            moc.performBlockAndWait({ () in
                if let photo = moc.objectWithID(photoID) as? Photo {
                    task(photo: photo, managedObjectContext: moc)
                } else {
                    println("Missing photo \(photoID)")
                }
            })
        })
        operation.queuePriority = priority
        operation.qualityOfService = qualityOfService
        startTask(photoID, type: type, operation: operation)
    }

    func discoverPhoto(photoID: NSManagedObjectID) {
        startPhotoTask(photoID, type: "discovery", priority: .High, qualityOfService: .Utility, task: { (photo: Photo, managedObjectContext: NSManagedObjectContext) in
            var error: NSError?

            if photo.stateEnum == .Broken {
                return
            }
            if photo.created == nil {
                photo.readData()
                if !managedObjectContext.save(&error) {
                    println("Coudn't save managedObjectContext: \(error)")
                }
            }
        })

        hashPhoto(photoID)
        // qualityPhoto(photoID)
    }

    func hashPhoto(photoID: NSManagedObjectID) {
        startPhotoTask(photoID, type: "hash", priority: .Normal, qualityOfService: .Background, task: { (photo: Photo, managedObjectContext: NSManagedObjectContext) in
            var error: NSError?

            if photo.stateEnum == .Broken {
                return
            }
            photo.genFhash()
            photo.genAhash()

            photo.mutableSetValueForKey("duplicates").removeAllObjects()
            if !managedObjectContext.save(&error) {
                println("Coudn't save managedObjectContext: \(error)")
            }

            let appDelegate = NSApplication.sharedApplication().delegate as AppDelegate
            let dups = appDelegate.bkTree.find(photo.objectID, n: 0, moc: managedObjectContext)
            if dups.count > 0 {
                for p in dups {
                    let ph = managedObjectContext.objectWithID(p) as Photo
                    let duplicates = photo.mutableSetValueForKey("duplicates")
                    if !duplicates.containsObject(ph) {
                        duplicates.addObject(ph)
                    }
                }
            }
            appDelegate.bkTree.insert(photoID, moc: managedObjectContext)

            photo.stateEnum = .Known

            if !managedObjectContext.save(&error) {
                println("Coudn't save managedObjectContext: \(error)")
            }
        })
    }

    func qualityPhoto(photoID: NSManagedObjectID) {
        startPhotoTask(photoID, type: "quality", priority: .Normal, qualityOfService: .Background, task: { (photo: Photo, managedObjectContext: NSManagedObjectContext) in
            var error: NSError?

            photo.genQualityMeasures()
            if !managedObjectContext.save(&error) {
                println("Coudn't save moc: \(error)")
            }
        })
    }
}

// http://www.raywenderlich.com/76341/use-nsoperation-nsoperationqueue-swift
private func createPrivateMOC() -> NSManagedObjectContext {
    let moc =  NSManagedObjectContext(concurrencyType: .PrivateQueueConcurrencyType)
    moc.persistentStoreCoordinator = CoreDataStackManager.sharedManager.persistentStoreCoordinator
    moc.undoManager = nil
    return moc
}