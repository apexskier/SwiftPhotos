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
    
    @IBOutlet var window: NSWindow!
    
    // @IBOutlet var importArrayController: NSArrayController!
    @IBOutlet var outputTextField: NSTextField!
    
    @IBOutlet var tableView: NSTableView!
    @IBOutlet var outputField : NSTextField!
    @IBOutlet var imageView: NSImageView!
    
    /// Managed object context for the view controller (which is bound to the persistent store coordinator for the application).
    private lazy var managedObjectContext: NSManagedObjectContext = {
        let moc = NSManagedObjectContext(concurrencyType: .MainQueueConcurrencyType)
        moc.persistentStoreCoordinator = CoreDataStackManager.sharedManager.persistentStoreCoordinator
        return moc
    }()
    
    var inputs: PathArrayTable = PathArrayTable()
    
    var pendingOperations = PhotoOperations()
    
    func applicationDidFinishLaunching(aNotification: NSNotification?) {
        // Insert code here to initialize your application
        outputField.stringValue = "Hello, World!"
        
        tableView.setDataSource(inputs)
    }
    
    func applicationWillTerminate(aNotification: NSNotification?) {
        // Insert code here to tear down your application
    }
    
    @IBAction func chooseOutputClick(sender: NSButton) {
        var filePicker = NSOpenPanel()
        filePicker.canChooseDirectories = true
        filePicker.canChooseFiles = false
        filePicker.allowsMultipleSelection = false
        
        var result = filePicker.runModal()
        
        if result == NSOKButton {
            println("OK Clicked")
            var outputPath = filePicker.URL!
            outputTextField.stringValue = outputPath.relativePath!
            println(outputPath.relativePath)
            filePicker.close()
        } else if result == NSCancelButton {
            println("Cancel Clicked")
        }
    }
    @IBAction func addImportSourceClick(sender: AnyObject) {
        var filePicker = NSOpenPanel()
        filePicker.canChooseDirectories = true
        filePicker.canChooseFiles = false
        filePicker.allowsMultipleSelection = true
        
        var result = filePicker.runModal()
        
        if result == NSOKButton {
            for url in filePicker.URLs as [NSURL] {
                inputs.append(url)
                println(url.description)
            }
            tableView.reloadData()
            filePicker.close()
        }
    }
    @IBAction func removeImportSourceClick(sender: NSButtonCell) {
        var idx = tableView.selectedRow
        if idx != -1 {
            inputs.removeAt(idx)
        }
        tableView.reloadData()
    }
    
    @IBAction func openButtonClick(sender: AnyObject) { openOpen() }
    @IBAction func openClick(sender: NSMenuItem) { openOpen() }
    func openOpen() {
        var filePicker = NSOpenPanel()
        filePicker.canChooseDirectories = false
        filePicker.canChooseFiles = true
        filePicker.allowsMultipleSelection = true
        
        var result = filePicker.runModal()
        
        if result == NSOKButton {
            if let firstURL = filePicker.URLs.first as NSURL! {
                var anyError: NSError?
                let taskContext = privateQueueContext(&anyError)
                if taskContext == nil {
                    println("Error creating fetching context: \(anyError)")
                    fatalError("Couldn't create fetching context.")
                    return
                }
                
                let path = firstURL.absoluteString!
                var photo = NSEntityDescription.insertNewObjectForEntityForName("Photo", inManagedObjectContext: taskContext) as Photo
                photo.filepath = path
                photo.readData()
                
                displayImage(photo)
                startPhotoOperations(photo)
            }
            filePicker.close()
        }
    }
    
    func displayImage(photo: Photo) {
        self.outputField.stringValue = "Getting photo!"
        
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
        }
    }
    
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
                self.outputField.stringValue += "\nphash: \(photo.hash)"
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
