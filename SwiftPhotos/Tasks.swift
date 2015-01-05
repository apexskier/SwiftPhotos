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

enum TaskType {
    case Deletion
    case Discovery
    case Hash
    case Move
    case Quality
}

class TaskManager {
    class var sharedManager: TaskManager {
        struct Singleton {
            static let taskManager = TaskManager()
        }
        
        return Singleton.taskManager
    }

    var operationsInProgress = [NSManagedObjectID: [TaskType: NSBlockOperation]]()

    var queue: NSOperationQueue = {
        var q = NSOperationQueue()
        q.name = "com.camlittle.SwiftPhotos.Tasks"
        q.maxConcurrentOperationCount = 1
        // q.suspended = true
        return q
    }()

    var managedObjectContext: NSManagedObjectContext = {
        // http://www.objc.io/issue-2/common-background-practices.html
        let moc =  NSManagedObjectContext(concurrencyType: .PrivateQueueConcurrencyType)
        moc.persistentStoreCoordinator = CoreDataStackManager.sharedManager.persistentStoreCoordinator
        moc.undoManager = nil
        moc.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        
        NSNotificationCenter.defaultCenter().addObserverForName(NSManagedObjectContextDidSaveNotification, object: nil, queue: nil, usingBlock: { (notification: NSNotification!) in
            if notification.object as NSManagedObjectContext != moc {
                moc.mergeChangesFromContextDidSaveNotification(notification)
            }
        })
        
        return moc
    }()
    
    func cancelPhoto(id: NSManagedObjectID) {
        if let tasks = operationsInProgress.removeValueForKey(id) {
            for (type, task) in tasks {
                task.cancel()
            }
        }
    }

    func cancelTask(id: NSManagedObjectID, type: TaskType) {
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
    private func startTask(id: NSManagedObjectID, type: TaskType, operation: NSBlockOperation) {
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
            NSNotificationCenter.defaultCenter().postNotificationName("completedTask", object: nil)
            NSNotificationCenter.defaultCenter().postNotificationName("completedTask.\(type)", object: nil)
            self.cancelTask(id, type: type)
        }

        if operationsInProgress[id] == nil {
            operationsInProgress[id] = [TaskType: NSBlockOperation]()
        }
        operationsInProgress[id]![type] = operation
        queue.addOperation(operation)
    }

    func deletePhoto(photoID: NSManagedObjectID) {
        if let currentOperationContainer = self.operationsInProgress[photoID] {
            if let _ = currentOperationContainer[.Deletion] {
                return
            }
        }
        
        let operation = NSBlockOperation(block: {
            self.managedObjectContext.performBlockAndWait({
                if let photo = self.managedObjectContext.objectWithID(photoID) as? Photo {
                    var error: NSError?
                    var fileURL = photo.fileURL
                    
                    let fm = NSFileManager.defaultManager()
                    if fm.fileExistsAtPath(fileURL.relativePath!) {
                        if !fm.removeItemAtURL(fileURL, error: &error) {
                            println("Didn't remove file: \(fileURL.relativePath?)")
                        }
                    }

                    removeEmptyDirs(fileURL)
                    
                    let appDelegate = NSApplication.sharedApplication().delegate as AppDelegate
                    appDelegate.bkTree.remove(photoID: photoID, managedObjectContext: self.managedObjectContext)
                    
                    if let tasks = self.operationsInProgress.removeValueForKey(photoID) {
                        for (type, task) in tasks {
                            task.cancel()
                        }
                    }
                    
                    // TODO: figure this out
                    self.managedObjectContext.deleteObject(photo)
                    //photo.stateEnum = .Broken

                    if !self.managedObjectContext.save(&error) {
                        fatalError("Didn't save background managedObjectContext: \(error)")
                    }
                    println("Deleted \(photoID)")
                } else {
                    println("Missing photo \(photoID)")
                }
            })
        })
        
        // cancel all other tasks, then wait for them to finish.
        // this *should* prevent any other tasks from existing that would access this photoID
        if let currentOperationContainer = self.operationsInProgress[photoID] {
            for (type, op) in currentOperationContainer {
                op.cancel()
                operation.addDependency(op)
            }
        }
        
        // http://nshipster.com/nsoperation/
        operation.queuePriority = .VeryHigh
        operation.qualityOfService = .UserInitiated
        
        startTask(photoID, type: .Deletion, operation: operation)
    }

    func discoverPhoto(photoID: NSManagedObjectID) {
        let operation = NSBlockOperation(block: {
            self.managedObjectContext.performBlockAndWait({
                if let photo = self.managedObjectContext.objectWithID(photoID) as? Photo {
                    if photo.stateEnum == .Broken {
                        return
                    }
                    if photo.created == nil {
                        photo.readData()
                        var error: NSError?
                        if !self.managedObjectContext.save(&error) {
                            fatalError("Didn't save background managedObjectContext: \(error)")
                        }
                    }
                } else {
                    fatalError("Missing photo \(photoID)")
                }
            })
        })
        operation.queuePriority = .VeryHigh
        operation.qualityOfService = .UserInitiated
        
        startTask(photoID, type: .Discovery, operation: operation)

        hashPhoto(photoID)
        qualityPhoto(photoID)
    }

    func hashPhoto(photoID: NSManagedObjectID) {
        let operation = NSBlockOperation(block: {
            self.managedObjectContext.performBlockAndWait({
                if let photo = self.managedObjectContext.objectWithID(photoID) as? Photo {
                    if photo.stateEnum == .Broken {
                        return
                    }
                    photo.genFhash()
                    photo.genAhash()
                    
                    photo.mutableSetValueForKey("duplicates").removeAllObjects()
                    
                    let appDelegate = NSApplication.sharedApplication().delegate as AppDelegate
                    let dups = appDelegate.bkTree.search(photoID: photo.objectID, distance: 0, managedObjectContext: self.managedObjectContext)
                    if dups.count > 0 {
                        for p in dups {
                            let ph = self.managedObjectContext.objectWithID(p) as Photo
                            let duplicates = photo.mutableSetValueForKey("duplicates")
                            if !duplicates.containsObject(ph) {
                                duplicates.addObject(ph)
                            }
                        }
                    }
                    appDelegate.bkTree.insert(photoID: photoID, managedObjectContext: self.managedObjectContext)
                    
                    photo.stateEnum = .Known

                    var error: NSError?
                    if !self.managedObjectContext.save(&error) {
                        fatalError("Didn't save background managedObjectContext: \(error)")
                    }
                } else {
                    fatalError("Missing photo \(photoID)")
                }
            })
        })
        operation.queuePriority = .Normal
        operation.qualityOfService = .Background
        
        startTask(photoID, type: .Hash, operation: operation)
    }
    
    func movePhoto(photoID: NSManagedObjectID, outputURL: NSURL) {
        let operation = NSBlockOperation(block: {
            self.managedObjectContext.performBlockAndWait({
                if let photo = self.managedObjectContext.objectWithID(photoID) as? Photo {
                    var error: NSError?
                    var fileURL = photo.fileURL
                    
                    if photo.stateEnum == .Broken {
                        return
                    }

                    let filename = photo.fileURL.lastPathComponent
                    if filename == nil {
                        photo.stateEnum = .Broken
                        return
                    }

                    var newURL: NSURL = {
                        if let date = photo.created {
                            let df = NSDateFormatter()
                            df.dateFormat = "yyyy"
                            let year = df.stringFromDate(date)
                            df.dateFormat = "MM-MMMM"
                            let month = df.stringFromDate(date)

                            return outputURL.URLByAppendingPathComponent(year).URLByAppendingPathComponent(month).URLByAppendingPathComponent(filename!)
                        } else {
                            return outputURL.URLByAppendingPathComponent("undated").URLByAppendingPathComponent(filename!)
                        }
                    }()

                    if fileURL.relativePath! == newURL.relativePath! {
                        // already in the correct location
                        return
                    }

                    let fm = NSFileManager.defaultManager()

                    // make the new filepath unique
                    var count = 1
                    while (fm.fileExistsAtPath(newURL.relativePath!)) {
                        let ext = newURL.pathExtension!
                        newURL = newURL.URLByDeletingPathExtension!.URLByAppendingPathExtension("\(count).\(ext)")
                    }
                    
                    if let dir = newURL.URLByDeletingLastPathComponent {
                        // update photo information and save before moving (avoids filemonitor issues)
                        // TODO: This could be avoided if my filemonitor didn't see my changes
                        photo.fileURL = newURL
                        if !self.managedObjectContext.save(&error) {
                            fatalError("Didn't save background managedObjectContext: \(error)")
                        }

                        // create new location if it doesn't exist
                        if !fm.createDirectoryAtURL(dir, withIntermediateDirectories: true, attributes: nil, error: &error) {
                            fatalError("Couldn't verify directory \(dir): \(error)")
                        }
                        // move photo to new location
                        if !fm.moveItemAtURL(fileURL, toURL: newURL, error: &error) {
                            println("Couldn't move photo to \(newURL): \(error)")
                        }

                        // clean up after ourselves
                        removeEmptyDirs(fileURL)
                    } else {
                        fatalError("Couldn't get new dir.")
                    }
                } else {
                    fatalError("Missing photo \(photoID)")
                }
            })
        })
        operation.queuePriority = .High
        operation.qualityOfService = .Utility
        
        startTask(photoID, type: .Move, operation: operation)
    }

    func qualityPhoto(photoID: NSManagedObjectID) {
        let operation = NSBlockOperation(block: {
            self.managedObjectContext.performBlockAndWait({
                if let photo = self.managedObjectContext.objectWithID(photoID) as? Photo {
                    photo.genQualityMeasures()

                    var error: NSError?
                    if !self.managedObjectContext.save(&error) {
                        fatalError("Didn't save background managedObjectContext: \(error)")
                    }
                } else {
                    fatalError("Missing photo \(photoID)")
                }
            })
        })
        operation.queuePriority = .Low
        operation.qualityOfService = .Background
        
        startTask(photoID, type: .Quality, operation: operation)
    }
}

func removeEmptyDirs(start: NSURL) {
    var fm = NSFileManager.defaultManager()
    var error: NSError?

    var dir = start.URLByDeletingLastPathComponent!
    var contents = fm.contentsOfDirectoryAtURL(dir, includingPropertiesForKeys: nil, options: NSDirectoryEnumerationOptions.SkipsHiddenFiles, error: &error)
    if contents == nil {
        println("ERROR")
    }
    while contents!.count == 0 {
        if !fm.removeItemAtURL(dir, error: &error) {
            println("Didn't remove file: \(dir.relativePath?)")
        }
        dir = dir.URLByDeletingLastPathComponent!
        contents = fm.contentsOfDirectoryAtURL(dir, includingPropertiesForKeys: nil, options: NSDirectoryEnumerationOptions.SkipsHiddenFiles, error: &error)
        if contents == nil {
            println("ERROR")
        }
    }
}