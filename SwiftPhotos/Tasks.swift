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
                if currentOperation.executing {
                    currentOperation.cancel()
                } else if currentOperation.finished || currentOperation.cancelled {
                    // add operation as normal
                } else {
                    return
                }
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
        if let currentOperationContainer = self.operationsInProgress[photoID] {
            if let currentOperation = currentOperationContainer[type] {
                if currentOperation.executing {
                    // currentOperation.cancel()
                } else if currentOperation.finished || currentOperation.cancelled {
                    // add operation as normal
                } else {
                    return
                }
            }
        }
        
        let operation = NSBlockOperation(block: {
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
        // http://nshipster.com/nsoperation/
        operation.queuePriority = priority
        operation.qualityOfService = qualityOfService
        startTask(photoID, type: type, operation: operation)
    }
    
    func deletePhoto(photoID: NSManagedObjectID) {
        self.cancelPhoto(photoID)
        
        startPhotoTask(photoID, type: "deletion", priority: .VeryHigh, qualityOfService: .UserInitiated, task: { (photo: Photo, managedObjectContext: NSManagedObjectContext) in
            var error: NSError?
            var fileURL = photo.fileURL
            
            if photo.stateEnum != .Broken {
                var removed = NSFileManager.defaultManager().removeItemAtURL(fileURL, error: &error)
                if !removed {
                    println("Didn't remove file: \(fileURL.relativePath?)")
                }
                let appDelegate = NSApplication.sharedApplication().delegate as AppDelegate
                appDelegate.bkTree.remove(photoID: photoID, managedObjectContext: managedObjectContext)
            }
            
            self.cancelPhoto(photoID)
            
            managedObjectContext.deleteObject(photo)
            if !managedObjectContext.save(&error) {
                fatalError("Error saving: \(error)")
            }
        })
    }

    func discoverPhoto(photoID: NSManagedObjectID) {
        startPhotoTask(photoID, type: "discovery", priority: .VeryHigh, qualityOfService: .Utility, task: { (photo: Photo, managedObjectContext: NSManagedObjectContext) in
            if photo.stateEnum == .Broken {
                return
            }
            if photo.created == nil {
                var error: NSError?
                photo.readData()
                if !managedObjectContext.save(&error) {
                    println("Coudn't save managedObjectContext: \(error)")
                }
            }
        })

        hashPhoto(photoID)
        qualityPhoto(photoID)
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
            let dups = appDelegate.bkTree.search(photoID: photo.objectID, distance: 0, managedObjectContext: managedObjectContext)
            if dups.count > 0 {
                for p in dups {
                    let ph = managedObjectContext.objectWithID(p) as Photo
                    let duplicates = photo.mutableSetValueForKey("duplicates")
                    if !duplicates.containsObject(ph) {
                        duplicates.addObject(ph)
                    }
                }
            }
            appDelegate.bkTree.insert(photoID: photoID, managedObjectContext: managedObjectContext)

            photo.stateEnum = .Known

            if !managedObjectContext.save(&error) {
                println("Coudn't save managedObjectContext: \(error)")
            }
        })
    }
    
    func movePhoto(photoID: NSManagedObjectID, outputURL: NSURL) {
        startPhotoTask(photoID, type: "move", priority: .High, qualityOfService: .Utility, task: { (photo: Photo, managedObjectContext: NSManagedObjectContext) in
            var error: NSError?
            let photo = managedObjectContext.objectWithID(photoID) as Photo
            
            var fileURL = photo.fileURL
            
            if photo.stateEnum == .Broken {
                return
            }
            
            let date = photo.created
            let filename = photo.fileURL.lastPathComponent
            if date == nil || filename == nil {
                photo.stateEnum == .Broken
                if !managedObjectContext.save(&error) {
                    fatalError("Error saving: \(error)")
                }
                return
            }
            
            let df = NSDateFormatter()
            df.dateFormat = "yyyy"
            let year = df.stringFromDate(date!)
            df.dateFormat = "MM-MMMM"
            let month = df.stringFromDate(date!)
            
            let newURL = outputURL.URLByAppendingPathComponent(year).URLByAppendingPathComponent(month).URLByAppendingPathComponent(filename!)
            
            let fm = NSFileManager.defaultManager()
            
            if let dir = newURL.URLByDeletingLastPathComponent {
                // create new location if it doesn't exist
                if !fm.createDirectoryAtURL(dir, withIntermediateDirectories: true, attributes: nil, error: &error) {
                    fatalError("Couldn't verify directory \(dir): \(error)")
                }
                // move photo to new location
                if !fm.moveItemAtURL(fileURL, toURL: newURL, error: &error) {
                    fatalError("Couldn't move photo to \(newURL): \(error)")
                }
                // update photo information
                photo.fileURL = newURL
                if !managedObjectContext.save(&error) {
                    fatalError("Error saving: \(error)")
                }
            } else {
                fatalError("Couldn't get new dir.")
            }
        })
    }

    func qualityPhoto(photoID: NSManagedObjectID) {
        startPhotoTask(photoID, type: "quality", priority: .Low, qualityOfService: .Background, task: { (photo: Photo, managedObjectContext: NSManagedObjectContext) in
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
    // http://www.objc.io/issue-2/common-background-practices.html
    let moc =  NSManagedObjectContext(concurrencyType: .PrivateQueueConcurrencyType)
    moc.persistentStoreCoordinator = CoreDataStackManager.sharedManager.persistentStoreCoordinator
    moc.undoManager = nil
    return moc
}