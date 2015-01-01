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
                    settings.inputs = NSMutableOrderedSet(array: [])
                    
                    if !self.managedObjectContext.save(&anyError) {
                        fatalError("Error saving: \(anyError)")
                    }
                } else {
                    settings = sources[0] as Settings
                }
            } else {
                fatalError("Error fetching settings: \(anyError)")
            }
            return settings
        }
    }
    
    private lazy var _outputSet: Bool = {
        if self.settings.output != nil && self.settings.output!.path != "" {
            return true
        }
        return false
    }()
    var outputSet: Bool {
        get {
            return _outputSet
        }
        set(val) {
            // start moving files if output wasn't already set
            if !_outputSet && val {
                var error: NSError?
                outputURL = self.settings.output!.url!
                let request = NSFetchRequest(entityName: "Photo")
                let fetchedPhotos = self.managedObjectContext.executeFetchRequest(request, error: &error)
                if let photos = fetchedPhotos as? [Photo] {
                    for photo in photos {
                        TaskManager.sharedManager.movePhoto(photo.objectID, outputURL: outputURL!)
                    }
                }
            }
            _outputSet = val
        }
    }
    
    lazy var outputURL: NSURL? = {
        return self.settings.output?.url
    }()

    var bkTree = PhotoBKTree()
    
    func showInfoHUD() {()
        // TODO
    }

    private var observers: [AnyObject] = []
    
    func applicationDidFinishLaunching(aNotification: NSNotification?) {
        // Insert code here to initialize your application

        NSNotificationCenter.defaultCenter().addObserverForName(NSManagedObjectContextDidSaveNotification, object: nil, queue: nil, usingBlock: { (notification: NSNotification!) in
            if notification.object as NSManagedObjectContext != self.managedObjectContext {
                self.managedObjectContext.performBlock({
                    self.managedObjectContext.mergeChangesFromContextDidSaveNotification(notification)
                })
            }
        })

        if let output = settings.output {
            startProcessingFolder(output.path)
        }
        if settings.inputs.count > 0 {
            let folders: [Folder] = settings.inputs.objectEnumerator().allObjects.reverse() as [Folder]
            for folder in folders {
                startProcessingFolder(folder.path)
            }
        }

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
        TaskManager.sharedManager.pause()
        if let path = NSURL(string: pathStr) {
            if let dirEnumerator: NSDirectoryEnumerator = NSFileManager.defaultManager().enumeratorAtURL(
                path,
                includingPropertiesForKeys: [NSURLPathKey, NSURLIsDirectoryKey],
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
                
                NSNotificationCenter.defaultCenter().postNotificationName("photoAdded", object: nil)
            } else {
                println("Couldn't initialize NSDirectoryEnumerator for \(path)")
            }
        } else {
            println("Couldn't create URL for \(pathStr)")
        }
        TaskManager.sharedManager.resume()
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

    func changeFound(url: NSURL) {
        let fm = NSFileManager.defaultManager()
        if fm.fileExistsAtPath(url.relativePath!) {
            addFile(url)
            NSNotificationCenter.defaultCenter().postNotificationName("photoAdded", object: nil)
        } else {
            if let photo = photoFromURL(url) {
                photo.stateEnum = .Broken
                TaskManager.sharedManager.deletePhoto(photo.objectID)
            }
            NSNotificationCenter.defaultCenter().postNotificationName("photoRemoved", object: nil)
        }
    }
    
    func addFile(url: NSURL) {
        var error: NSError?
        var photo: Photo?
        
        photo = photoFromURL(url)
        if photo == nil {
            photo = NSEntityDescription.insertNewObjectForEntityForName("Photo", inManagedObjectContext: self.managedObjectContext) as? Photo
            if photo == nil {
                fatalError("Didn't create new photo")
            }

            photo!.filepath = url.absoluteString!
            if !self.managedObjectContext.save(&error) {
                fatalError("Error saving: \(error)")
            }
        }

        if let photo = photo {
            if photo.stateEnum != .New {
                photo.stateEnum = .New
                if !self.managedObjectContext.save(&error) {
                    fatalError("Error saving: \(error)")
                }
            }
            TaskManager.sharedManager.discoverPhoto(photo.objectID)
            if outputSet {
                TaskManager.sharedManager.movePhoto(photo.objectID, outputURL: outputURL!)
            }
        } else {
            fatalError("No photo for url: \(url)")
        }
    }
}