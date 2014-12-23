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
                        fatalError("Error saving: \(anyError)")
                    }
                } else {
                    settings = sources[0] as Settings
                }
            } else {
                println("Error fetching: \(anyError)")
                fatalError("Fetch failed.")
            }
            return settings
        }
    }

    var bkTree = PhotoBKTree()
    
    func showInfoHUD() {()
        // TODO
    }

    func managedObjectSaved(notification: NSNotification) {
        let sender = notification.object as NSManagedObjectContext
        if sender !== self.managedObjectContext {
            NSLog("******** Saved context in other thread")
            managedObjectContext.performBlock {
                self.managedObjectContext.mergeChangesFromContextDidSaveNotification(notification)
            }
        } else {
            println("******** Saved context in main thread")
        }
    }

    var observers: [AnyObject] = []

    //let discoveryWorker = DiscoveryWorker()
    var hashWorker: HashWorker?
    
    func applicationDidFinishLaunching(aNotification: NSNotification?) {
        // Insert code here to initialize your application
        //NSNotificationCenter.defaultCenter().addObserver(self, selector: "managedObjectSaved", name: NSManagedObjectContextDidSaveNotification, object: nil)

        /*if let output = settings.output {
            startProcessingFolder(output.path)
        }
        if settings.imports.count > 0 {
            let folders: [Folder] = settings.imports.objectEnumerator().allObjects.reverse() as [Folder]
            for folder in folders {
                startProcessingFolder(folder.path)
            }
        }*/
        hashWorker = HashWorker(delegate: self)

        //discoveryWorker.start()
        hashWorker!.start()

        // start the filesystem monitor
        FileSystemMonitor.sharedManager.start()
    }
    
    func applicationWillTerminate(aNotification: NSNotification?) {
        // Insert code here to tear down your application
        for observer in observers {
            NSNotificationCenter.defaultCenter().removeObserver(observer)
        }
        //NSNotificationCenter.defaultCenter().removeObserver(self)
        var error: NSError?
        if !self.managedObjectContext.save(&error) {
            fatalError("Error saving: \(error)")
        }
    }
    
    func applicationShouldHandleReopen(sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            let storyboard = NSStoryboard(name: "Main", bundle: nil)
            let initialView = storyboard?.instantiateInitialController() as NSWindowController
            let mainWindow = initialView.window?
            if mainWindow != nil {
                mainWindow!.makeKeyAndOrderFront(self)
            }
        }
        return true
    }
    
    func startProcessingFolder(pathStr: String) {
        if let path = NSURL(string: pathStr) {
            if let dirEnumerator: NSDirectoryEnumerator = fileManager.enumeratorAtURL(
                path,
                includingPropertiesForKeys: [NSURLPathKey, NSURLNameKey, NSURLIsDirectoryKey],
                options: NSDirectoryEnumerationOptions.SkipsHiddenFiles,
                errorHandler: { (url: NSURL!, error: NSError!) -> Bool in
                    if let u = url {
                        println("Error at \(u.relativePath?))")
                    }
                    println(error)
                    return true
                }) {
                /*var waitWindowController = WaitSheetController()
                var waitWindow = waitWindowController.window! as WaitSheet
                
                let storyboard = NSStoryboard(name: "Main", bundle: nil)
                let initialView = storyboard?.instantiateInitialController() as NSWindowController
                let mainWindow = initialView.window!
                
                mainWindow.beginSheet(waitWindow, completionHandler: nil)
                waitWindow.title = "Please Wait"
                waitWindow.contentText.stringValue = "Adding folder contents"
                waitWindow.titleText.stringValue = "Please wait."*/
                
                for url: NSURL in dirEnumerator.allObjects as [NSURL] {
                    var error: NSError?
                    var isDirObj: AnyObject?
                    let ext: String = NSString(string: url.pathExtension!).lowercaseString as String
                    if contains(Constants.allowedExtentions, ext) {
                        if !url.getResourceValue(&isDirObj, forKey: NSURLIsDirectoryKey, error: &error) {
                            println("Error getting resource from url '\(url)'.\n\(error)")
                        } else if let isDir = isDirObj as? NSNumber {
                            if isDir == 0 {
                                //waitWindow.contentText.stringValue = url.relativePath?
                                //println(url.relativePath?)
                                addFile(url)
                            }
                        }
                    }
                }
                
                NSNotificationCenter.defaultCenter().postNotificationName("newPhotos", object: nil)
            } else {
                println("Couldn't initialize NSDirectoryEnumerator for \(path)")
            }
        } else {
            println("Couldn't create URL for \(pathStr)")
        }
    }
    
    func photoFromURL(url: NSURL) -> Photo? {
        var error: NSError?
        if let path = url.absoluteString {
            let request = NSFetchRequest(entityName: "Photo")
            let predicate = NSPredicate(format: "filepath == %@",
                argumentArray: [path])
            request.predicate = predicate

            if let results = self.managedObjectContext.executeFetchRequest(request, error: &error) {
                if results.count > 0 {
                    return results[0] as? Photo
                }
            }
        }
        
        return nil
    }
    
    func addFile(url: NSURL) {
        var error: NSError?
        var photo: Photo?
        
        photo = photoFromURL(url)
        if photo == nil {
            if let photo = NSEntityDescription.insertNewObjectForEntityForName("Photo", inManagedObjectContext: self.managedObjectContext) as? Photo {

                photo.filepath = url.absoluteString!
                photo.stateEnum = .New

                if !self.managedObjectContext.save(&error) {
                    fatalError("Error saving: \(error)")
                }

                // TODO: start up discover worker
            }
        }
    }
    
    var secondary_queue = dispatch_queue_create("camlittle.SwiftPhotos.secondary_queue", nil)
    
    func changeFound(url: NSURL, change: FileChange) {
        switch change {
        case .Removed:
            if let photo = photoFromURL(url) {
                photo.stateEnum = .Broken
                var error: NSError?
                AppDelegate.deletePhoto(photo.objectID, error: &error)
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
    
    class func deletePhoto(photoID: NSManagedObjectID, error: NSErrorPointer) {
        let moc = NSManagedObjectContext(concurrencyType: .MainQueueConcurrencyType)
        moc.persistentStoreCoordinator = CoreDataStackManager.sharedManager.persistentStoreCoordinator

        let photo = moc.objectWithID(photoID) as Photo

        var fileURL = photo.fileURL
        var filePath = photo.filepath
        
        if photo.stateEnum != .Broken {
            var removed = NSFileManager.defaultManager().removeItemAtURL(fileURL, error: error)
            if !removed {
                println("Didn't remove file: \(fileURL.relativePath?)")
                return
            }
        }

        for dup in photo.duplicates {
            dup.mutableSetValueForKey("duplicates").removeObject(photo)
        }
        
        moc.deleteObject(photo)
        if !moc.save(error) {
            fatalError("Error saving: \(error)")
        }
    }

    func findDuplicates() {
        /*for photo in photos {

        }*/
    }
}