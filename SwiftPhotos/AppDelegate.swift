//
//  AppDelegate.swift
//  SwiftPhotos
//
//  Created by Cameron Little.
//

import Cocoa
import CoreData
import Dispatch
import Foundation
import Quartz

class AppDelegate: NSObject, NSApplicationDelegate {
    
    //@IBOutlet var imageBrowserView: ImageBrowserWindowController!
    
    /// Managed object context for the view controller (which is bound to the persistent store coordinator for the application).
    lazy var managedObjectContext: NSManagedObjectContext = {
        let moc = NSManagedObjectContext(concurrencyType: .MainQueueConcurrencyType)
        moc.persistentStoreCoordinator = CoreDataStackManager.sharedManager.persistentStoreCoordinator
        return moc
    }()
    
    var fileManager = NSFileManager()
    
    var settings: Settings {
        get {
            var settings: Settings
            var anyError: NSError?
            
            let request = NSFetchRequest(entityName: "Settings")
            let fetchedSources = self.managedObjectContext.executeFetchRequest(request, error: &anyError)
            if let sources = fetchedSources {
                if sources.count == 0 {
                    settings = NSEntityDescription.insertNewObjectForEntityForName("Settings", inManagedObjectContext: self.managedObjectContext) as Settings
                    var folder = NSEntityDescription.insertNewObjectForEntityForName("Folder", inManagedObjectContext: self.managedObjectContext) as Folder
                    folder.path = ""
                    settings.output = folder
                    settings.imports = NSMutableOrderedSet(array: [])
                    
                    if !self.managedObjectContext.save(&anyError) {
                        println("Error saving batch: \(anyError)")
                        fatalError("Saving batch failed.")
                    }
                    managedObjectContext.reset()
                } else {
                    settings = sources[sources.count - 1] as Settings
                }
            } else {
                println("Error fetching: \(anyError)")
                fatalError("Fetch failed.")
            }
            return settings
        }
    }
    
    var photos: [Photo] {
        get {
            var error: NSError?
            let request = NSFetchRequest(entityName: "Photo")
            let sortDescriptor = NSSortDescriptor(key: "created", ascending: true)
            request.sortDescriptors = NSArray(array: [sortDescriptor])
            
            if let results = self.managedObjectContext.executeFetchRequest(request, error: &error) {
                return results as [Photo]
            } else {
                return []
            }
        }
    }
    
    var pendingOperations = PhotoOperations()
    
    func applicationDidFinishLaunching(aNotification: NSNotification?) {
        // Insert code here to initialize your application
        if settings.imports.count > 0 {
            for folder in settings.imports.objectEnumerator().allObjects as [Folder] {
                startProcessingFolder(folder.path)
            }
        }
    }
    
    func startProcessingFolder(path: String) {
        let path = NSURL(string: path)!
        if let dirEnumerator: NSDirectoryEnumerator = fileManager.enumeratorAtURL(
            path,
            includingPropertiesForKeys: [NSURLPathKey, NSURLNameKey, NSURLIsDirectoryKey],
            options: NSDirectoryEnumerationOptions.SkipsHiddenFiles,
            errorHandler: { (url: NSURL!, error: NSError!) -> Bool in
                if let u = url {
                    println("Error at \(url.relativePath!))")
                }
                println(error)
                return true
        }) {
            for url: NSURL in dirEnumerator.allObjects as [NSURL] {
                var error: NSError?
                var isDirObj: AnyObject?
                
                if !url.getResourceValue(&isDirObj, forKey: NSURLIsDirectoryKey, error: &error) {
                    println("Error getting resource from url '\(url)'.\n\(error)")
                } else if let isDir = isDirObj as? NSNumber {
                    if isDir == 0 {
                        //let photoDescription = NSEntityDescription.entityForName("Photo", inManagedObjectContext: self.managedObjectContext)
                        let request = NSFetchRequest(entityName: "Photo")
                        let predicate = NSPredicate(format: "filepath == %@",
                            argumentArray: [url.absoluteString!])
                        request.predicate = predicate
                        let sortDescriptor = NSSortDescriptor(key: "filepath", ascending: true)
                        request.sortDescriptors = NSArray(array: [sortDescriptor])
                        
                        if let results = self.managedObjectContext.executeFetchRequest(request, error: &error) {
                            var photo: Photo
                            
                            if results.count > 0 {
                                photo = results[0] as Photo
                            } else {
                                photo = NSEntityDescription.insertNewObjectForEntityForName("Photo", inManagedObjectContext: self.managedObjectContext) as Photo
                                photo.filepath = url.absoluteString!
                                photo.stateEnum = .New
                                
                                if !self.managedObjectContext.save(&error) {
                                    println("Error saving batch: \(error)")
                                    fatalError("Saving batch failed.")
                                }
                            }
                            
                            startPhotoOperations(photo)
                        } else {
                            fatalError("Couldn't query photos: \(error)")
                        }
                    }
                }
            }
            
            NSNotificationCenter.defaultCenter().postNotificationName("newPhotos", object: nil)
        } else {
            println("Couldn't initialize NSDirectoryEnumerator for \(path)")
        }
    }
    
    func applicationWillTerminate(aNotification: NSNotification?) {
        // Insert code here to tear down your application
    }
    
    
    // Concurrent task management
    
    func startPhotoOperations(photo: Photo) {
        switch (photo.stateEnum) {
            case .New:
                discoverPhoto(photo)
            case .Known:
                println("Found a known photo")
            default:
                NSLog("Do nothing")
        }
    }
    
    func discoverPhoto(photo: Photo) {
        if let currentOperation = pendingOperations.hashesInProgress[photo.filepath] {
            return
        }
        
        let op = PhotoDiscoverer(photo: photo)
        op.completionBlock = {
            if op.cancelled {
                return
            }
            dispatch_async(dispatch_get_main_queue(), {
                self.pendingOperations.hashesInProgress.removeValueForKey(photo.filepath)
                return
            })
        }
        
        pendingOperations.hashesInProgress[photo.filepath] = op
        pendingOperations.hashesQueue.addOperation(op)
    }
}

// Creates a new Core Data stack and returns a managed object context associated with a private queue.
private func privateQueueContext(outError: NSErrorPointer) -> NSManagedObjectContext! {
    // It uses the same store and model, but a new persistent store coordinator and context.
    let localCoordinator = NSPersistentStoreCoordinator(managedObjectModel: CoreDataStackManager.sharedManager.managedObjectModel)
    var error: NSError?
    
    let persistentStore = localCoordinator.addPersistentStoreWithType(NSSQLiteStoreType, configuration: nil, URL: CoreDataStackManager.sharedManager.storeURL, options: nil, error:&error)
    if persistentStore == nil {
        if outError != nil {
            outError.memory = error
        }
        return nil
    }
    
    let context = NSManagedObjectContext(concurrencyType: .PrivateQueueConcurrencyType)
    context.persistentStoreCoordinator = localCoordinator
    context.undoManager = nil
    
    return context
}
