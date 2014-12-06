//
//  Storage.swift
//  SwiftPhotos
//
//  Created by Cameron Little on 11/25/14.
//  Copyright (c) 2014 Cameron Little. All rights reserved.
//

import Foundation
import AppKit
import CoreData

class Storage {
    
    class func sharedStore() -> Storage {
        struct Static {
            static var instance: Storage?
            static var token: dispatch_once_t = 0
        }
        dispatch_once(&Static.token, {
            Static.instance = Storage()
        })
        return Static.instance!
    }
    
    let managedObjectContext: NSManagedObjectContext = {
        let moc = NSManagedObjectContext(concurrencyType: NSManagedObjectContextConcurrencyType.MainQueueConcurrencyType)
        moc.undoManager = nil
        moc.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        
        return moc
    }()
    
    let managedObjectModel: NSManagedObjectModel = {
        let url = NSBundle.mainBundle().URLForResource("SwiftPhotos", withExtension: "momd")!
        let mom = NSManagedObjectModel(contentsOfURL: url)
        
        return mom!
    }()
    
    let persistentStoreCoordinator: NSPersistentStoreCoordinator
    
    init() {
        persistentStoreCoordinator = NSPersistentStoreCoordinator(managedObjectModel: managedObjectModel)
        let urls = NSFileManager.defaultManager().URLsForDirectory(NSSearchPathDirectory.DocumentDirectory, inDomains: NSSearchPathDomainMask.UserDomainMask)
        let docUrl: NSURL = urls[urls.count - 1] as NSURL
        let url = docUrl.URLByAppendingPathComponent("SwiftPhotos.storedata")
        
        let options = [NSMigratePersistentStoresAutomaticallyOption: true, NSInferMappingModelAutomaticallyOption: true]
        let error: NSErrorPointer = nil
        if persistentStoreCoordinator.addPersistentStoreWithType(NSSQLiteStoreType, configuration: nil, URL: url, options: options, error: error) == nil {
            println("\(error)")
        }
        
        managedObjectContext.persistentStoreCoordinator = persistentStoreCoordinator
    }
    
    func save() {
        let moc = managedObjectContext
        
        moc.performBlockAndWait {
            let error: NSErrorPointer = nil
            if moc.hasChanges && !moc.save(error) {
                println("\(error)")
            }
        }
    }
    
    func CreatePhoto(path: String) -> Photo {
        let entityName: NSString = "SwiftPhotos.Photo"
        let obj = NSEntityDescription.insertNewObjectForEntityForName(entityName, inManagedObjectContext: managedObjectContext) as Photo
        obj.filepath = path
        return obj
    }
    
    func objectWithID(objectID: NSManagedObjectID) -> NSManagedObject {
        return managedObjectContext.objectWithID(objectID)
    }
    
    func deleteObject(object: NSManagedObject) {
        let moc = managedObjectContext
        moc.performBlockAndWait {
            moc.deleteObject(object)
        }
    }
    
    deinit {
        save()
    }
    
}