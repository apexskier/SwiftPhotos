//
//  AppDelegate.swift
//  SwiftPhotos
//
//  Created by Cameron Little.
//

import Cocoa
import CoreData
import Foundation

class AppDelegate: NSObject, NSApplicationDelegate {
    
    //@IBOutlet var imageView: NSImageView!
    
    /// Managed object context for the view controller (which is bound to the persistent store coordinator for the application).
    lazy var managedObjectContext: NSManagedObjectContext = {
        let moc = NSManagedObjectContext(concurrencyType: .MainQueueConcurrencyType)
        moc.persistentStoreCoordinator = CoreDataStackManager.sharedManager.persistentStoreCoordinator
        return moc
    }()
    
    var settings: Settings {
        get {
            var settings: Settings
            var anyError: NSError?
            
            let request = NSFetchRequest(entityName: "Settings")
            let fetchedSources = self.managedObjectContext.executeFetchRequest(request, error: &anyError)
            if let sources = fetchedSources {
                if sources.count == 0 {
                    settings = NSEntityDescription.insertNewObjectForEntityForName("Settings", inManagedObjectContext: self.managedObjectContext) as Settings
                    settings.output = Folder()
                    
                    if !self.managedObjectContext.save(&anyError) {
                        println("Error saving batch: \(anyError)")
                        fatalError("Saving batch failed.")
                    }
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
    
    var testStr: String = ""
    
    var pendingOperations = PhotoOperations()
    
    func applicationDidFinishLaunching(aNotification: NSNotification?) {
        // Insert code here to initialize your application
        println("Starting application.")
        
        let fileManager = NSFileManager()
        
        for folder in settings.imports.objectEnumerator().allObjects as [Folder] {
            println("--------------------------\nStarting folder \(folder.path)")
            let path = NSURL(string: folder.path)!
            var count = 0
            //let path = NSURL(fileURLWithPath: folder.path)!
            println(path.absoluteString!)
            if let dirEnumerator: NSDirectoryEnumerator = fileManager.enumeratorAtURL(
                path,
                includingPropertiesForKeys: [NSURLPathKey, NSURLNameKey, NSURLIsDirectoryKey],
                options: NSDirectoryEnumerationOptions.SkipsHiddenFiles,
                errorHandler: { (url: NSURL!, error: NSError!) -> Bool in
                    if let u = url {
                        println("Error at \(url.absoluteString!))")
                    }
                        
                    println(error)
                    return true
            }) {
                for url: NSURL in dirEnumerator.allObjects as [NSURL] {
                    var error: NSError?
                    var isDir: NSNumber? = nil
                    count++
                    
                    /*
                    if url.getResourceValue(&isDir as AnyObject, forKey: NSURLIsDirectoryKey, error: &error) {
                        print("Error getting resource from url '\(url)'.\n\(error)")
                    } else if (!isDir) {
                    }*/
                }
            } else {
                println("Couldn't initialize NSDirectoryEnumerator for \(folder.path)")
            }
            println("Found \(count) files.")
        }
    }
    
    func applicationWillTerminate(aNotification: NSNotification?) {
        // Insert code here to tear down your application
    }
    
    /*func displayImage(photo: Photo) {
        /*self.outputField.stringValue = "Getting photo!"
        
        print("\(photo.state)")
        if photo.stateEnum != .Broken {
            self.outputField.stringValue = "Got \(photo.fileURL.description)\n"
            if photo.height > 0 {
                self.outputField.stringValue += "Size: \(photo.width)x\(photo.height)"
            }
            self.outputField.stringValue += "\nDate: \(photo.created.description)"
            var image = photo.getImage()
            //var ph = phash(image)
            //var ah = avghash(image)
            //self.outputField.stringValue += "\nphash: \(ph)"
            //self.outputField.stringValue += "\navghash: \(ah)"
            //self.outputField.stringValue += "\nhash ^ differences: \(hammingDistance(ph, ah))"
            imageView.image = image
        } else {
            self.outputField.stringValue = "Failed to get photo."
        }*/
    }*/
    
    func startPhotoOperations(photo: Photo) {
        switch (photo.stateEnum) {
            case .New:
                startHashingPhoto(photo)
            default:
                NSLog("Do nothing")
        }
    }
    
    func startHashingPhoto(photo: Photo) {
        if let currentOperation = pendingOperations.hashesInProgress[photo.fileURL] {
            return
        }
        
        let op = PhotoHasher(photo: photo)
        op.completionBlock = {
            if op.cancelled {
                return
            }
            dispatch_async(dispatch_get_main_queue(), {
                self.pendingOperations.hashesInProgress.removeValueForKey(photo.fileURL)
                self.testStr += "\nphash: \(photo.hash)"
            })
        }
        
        pendingOperations.hashesInProgress[photo.fileURL] = op
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
