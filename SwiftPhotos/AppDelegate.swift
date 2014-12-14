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

    var selectedPhoto: Photo?
    
    @IBOutlet weak var getInfoMenuItem: NSMenuItem!
    
    /// Mark: Constants
    struct Constants {
        static let allowedExtentions: [String] = ["jpeg", "jpg", "png", "tiff", "gif"]
    }
    
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
    
    func showInfoHUD() {()
        // TODO
    }
    
    func applicationDidFinishLaunching(aNotification: NSNotification?) {
        // Insert code here to initialize your application
        if settings.imports.count > 0 {
            for folder in settings.imports.objectEnumerator().allObjects as [Folder] {
                startProcessingFolder(folder.path)
            }
        }
        
        // start the filesystem monitor
        FileSystemMonitor.sharedManager.start()
    }
    
    func applicationWillTerminate(aNotification: NSNotification?) {
        // Insert code here to tear down your application
        var error: NSError?
        if !self.managedObjectContext.save(&error) {
            fatalError("Error saving: \(error)")
        }
        self.managedObjectContext.reset()
    }
    
    func applicationShouldHandleReopen(sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            // TODO: Open up main window
        }
        return true
    }
    
    func startProcessingFolder(path: String) {
        let path = NSURL(string: path)!
        if let dirEnumerator: NSDirectoryEnumerator = fileManager.enumeratorAtURL(
            path,
            includingPropertiesForKeys: [NSURLPathKey, NSURLNameKey, NSURLIsDirectoryKey],
            options: NSDirectoryEnumerationOptions.SkipsHiddenFiles,
            errorHandler: { (url: NSURL!, error: NSError!) -> Bool in
                if let u = url {
                    println("Error at \(u.relativePath!))")
                }
                println(error)
                return true
        }) {
            for url: NSURL in dirEnumerator.allObjects as [NSURL] {
                var error: NSError?
                var isDirObj: AnyObject?
                let ext: String = NSString(string: url.pathExtension!).lowercaseString as String
                if contains(Constants.allowedExtentions, ext) {
                    if !url.getResourceValue(&isDirObj, forKey: NSURLIsDirectoryKey, error: &error) {
                        println("Error getting resource from url '\(url)'.\n\(error)")
                    } else if let isDir = isDirObj as? NSNumber {
                        if isDir == 0 {
                            addFile(url)
                        }
                    }
                }
            }
            
            NSNotificationCenter.defaultCenter().postNotificationName("newPhotos", object: nil)
        } else {
            println("Couldn't initialize NSDirectoryEnumerator for \(path)")
        }
    }
    
    func photoFromURL(url: NSURL) -> Photo? {
        var error: NSError?
        let request = NSFetchRequest(entityName: "Photo")
        let predicate = NSPredicate(format: "filepath == %@",
            argumentArray: [url.absoluteString!])
        request.predicate = predicate
        
        if let results = self.managedObjectContext.executeFetchRequest(request, error: &error) {
            if results.count > 0 {
                return results[0] as? Photo
            }
        }
        
        return nil
    }
    
    func addFile(url: NSURL) {
        var error: NSError?
        var photo: Photo?
        
        photo = photoFromURL(url)
        if photo == nil {
            photo = NSEntityDescription.insertNewObjectForEntityForName("Photo", inManagedObjectContext: self.managedObjectContext) as? Photo
            photo!.filepath = url.absoluteString!
        }
        
        photo!.stateEnum = .New
        if !self.managedObjectContext.save(&error) {
            fatalError("Error saving: \(error)")
        }
        
        discoverPhoto(photo!)
    }
    
    // Concurrent task management
    var taskManager: TaskManager {
        get {
            return TaskManager.sharedManager
        }
    }
    
    func discoverPhoto(photo: Photo) {
        if let currentOperation = taskManager.pendingDiscoveries.inProgress[photo.filepath] {
            return
        }
        
        let op = PhotoDiscoverer(photo: photo)
        op.completionBlock = {
            if op.cancelled {
                return
            }
            dispatch_async(dispatch_get_main_queue(), {
                NSNotificationCenter.defaultCenter().postNotificationName("completedTask", object: nil)
                self.taskManager.pendingDiscoveries.inProgress.removeValueForKey(photo.filepath)
                
                if photo.stateEnum == .Broken {
                    return
                }
                
                var error: NSError?
                if !self.managedObjectContext.save(&error) {
                    fatalError("Error saving: \(error)")
                }
                self.hashPhoto(photo)
                return
            })
        }
        
        taskManager.pendingDiscoveries.inProgress[photo.filepath] = op
        taskManager.pendingDiscoveries.queue.addOperation(op)
    }
    
    func hashPhoto(photo: Photo) {
        if photo.stateEnum == .New {
            if let currentOperation = taskManager.pendingHashes.inProgress[photo.filepath] {
                return
            }
            
            let op = PhotoHasher(photo: photo)
            op.completionBlock = {
                if op.cancelled {
                    return
                }
                dispatch_async(dispatch_get_main_queue(), {
                    NSNotificationCenter.defaultCenter().postNotificationName("completedTask", object: nil)
                    self.taskManager.pendingHashes.inProgress.removeValueForKey(photo.filepath)
                    var error: NSError?
                    if !self.managedObjectContext.save(&error) {
                        fatalError("Error saving: \(error)")
                    }
                    self.qualityPhoto(photo)
                    return
                })
            }
            
            taskManager.pendingHashes.inProgress[photo.filepath] = op
            taskManager.pendingHashes.queue.addOperation(op)
        }
    }
    
    func qualityPhoto(photo: Photo) {
        if let currentOperation = taskManager.pendingQuality.inProgress[photo.filepath] {
            return
        }
        
        let op = PhotoQualityGenerator(photo: photo)
        op.completionBlock = {
            if op.cancelled {
                return
            }
            dispatch_async(dispatch_get_main_queue(), {
                NSNotificationCenter.defaultCenter().postNotificationName("completedTask", object: nil)
                self.taskManager.pendingQuality.inProgress.removeValueForKey(photo.filepath)
                var error: NSError?
                if !self.managedObjectContext.save(&error) {
                    fatalError("Error saving: \(error)")
                }
                return
            })
        }
        
        taskManager.pendingQuality.inProgress[photo.filepath] = op
        taskManager.pendingQuality.queue.addOperation(op)
    }
    
    func changeFound(url: NSURL, change: FileChange) {
        switch change {
        case .Removed:
            if let photo = photoFromURL(url) {
                photo.stateEnum = .Broken
                var error: NSError?
                deletePhoto(photo, error: &error)
                if error != nil {
                    println("Error deleting photo: \(error)")
                }
            }
        case .Changed:
            fallthrough
        case .Added:
            addFile(url)
        }
        
        NSNotificationCenter.defaultCenter().postNotificationName("newPhotos", object: nil)
    }
    
    func deletePhoto(photo: Photo, error: NSErrorPointer) {
        var fileURL = photo.fileURL
        var filePath = photo.filepath
        
        if photo.stateEnum != .Broken {
            var removed = NSFileManager.defaultManager().removeItemAtURL(fileURL, error: error)
            if !removed {
                println("Didn't remove file: \(fileURL.relativePath!)")
                return
            }
        }
        
        if let task = taskManager.pendingDiscoveries.inProgress.removeValueForKey(filePath) {
            task.cancel()
        }
        if let task = taskManager.pendingHashes.inProgress.removeValueForKey(filePath) {
            task.cancel()
        }
        if let task = taskManager.pendingQuality.inProgress.removeValueForKey(filePath) {
            task.cancel()
        }
        
        managedObjectContext.deleteObject(photo)
        var err: NSError?
        if !self.managedObjectContext.save(&err) {
            fatalError("Error saving: \(err)")
        }
    }
}