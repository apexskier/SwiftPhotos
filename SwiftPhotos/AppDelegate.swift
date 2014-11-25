//
//  AppDelegate.swift
//  SwiftPhotos
//
//  Created by Cameron Little.
//

import Cocoa
import CoreData

class AppDelegate: NSObject, NSApplicationDelegate {
    
    @IBOutlet var window: NSWindow!
    
    @IBOutlet var importArrayController: NSArrayController!
    @IBOutlet var outputTextField: NSTextField!
    
    @IBOutlet var tableView: NSTableView!
    @IBOutlet var outputField : NSTextField!
    @IBOutlet var imageView: NSImageView!
    
    var storeURL = NSURL(fileURLWithPath: "~/.photos")
    
    lazy var inputs: PathArray = {
        let ctx = self.managedObjectContext!
        let fetchRequest = NSFetchRequest(entityName: "PathArray")
        var error: NSError?
        let fetchedResults = ctx.executeFetchRequest(fetchRequest, error: &error) as [PathArray]
        let c = fetchedResults.count
        if c == 1 {
            return fetchedResults[0] as PathArray
        } else if c > 1 {
            println("Found \(fetchedResults.count) importpaths")
        }
        let entity = NSEntityDescription.entityForName("PathArray", inManagedObjectContext: ctx)
        
        var pa = PathArray(entity: entity!, insertIntoManagedObjectContext: ctx)
        pa.paths = []
        pa.type = "inputs"
        if (ctx.save(&error)) {
            // Handle the error.
            println("Error saving ctx")
        }
        return pa
    }()
    
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
            println("OK Clicked")
            for url in filePicker.URLs as [NSURL] {
                inputs.append(url)
                println(url.description)
            }
            tableView.reloadData()
            filePicker.close()
        } else if result == NSCancelButton {
            println("Cancel Clicked")
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
        filePicker.canChooseDirectories = true
        filePicker.canChooseFiles = true
        filePicker.allowsMultipleSelection = true
        
        var result = filePicker.runModal()
        
        if result == NSOKButton {
            println("OK Clicked")
            if let firstURL = filePicker.URLs.first as NSURL! {
                var photo = Photo(url: firstURL)
                displayImage(photo)
                startPhotoOperations(photo)
            }
            filePicker.close()
        } else if result == NSCancelButton {
            println("Cancel Clicked")
        }
    }
    
    func displayImage(photo: Photo) {
        self.outputField.stringValue = "Getting photo!"
        
        if photo.state == .New {
            self.outputField.stringValue = "Got \(photo.fileURL.description)\n"
            if let height = photo.height {
                self.outputField.stringValue += "Size: \(photo.width!)x\(height)"
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
        switch (photo.state) {
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
    
    
    
    
    // MARK: - Core Data stack
    
    lazy var applicationDocumentsDirectory: NSURL = {
        // The directory the application uses to store the Core Data store file. This code uses a directory named "com.camlittle.SwiftPhotos" in the user's Application Support directory.
        let urls = NSFileManager.defaultManager().URLsForDirectory(.ApplicationSupportDirectory, inDomains: .UserDomainMask)
        let appSupportURL = urls[urls.count - 1] as NSURL
        return appSupportURL.URLByAppendingPathComponent("com.camlittle.SwiftPhotos")
        }()
    
    lazy var managedObjectModel: NSManagedObjectModel = {
        // The managed object model for the application. This property is not optional. It is a fatal error for the application not to be able to find and load its model.
        let modelURL = NSBundle.mainBundle().URLForResource("SwiftPhotos", withExtension: "momd")!
        return NSManagedObjectModel(contentsOfURL: modelURL)!
        }()
    
    lazy var persistentStoreCoordinator: NSPersistentStoreCoordinator? = {
        // The persistent store coordinator for the application. This implementation creates and return a coordinator, having added the store for the application to it. (The directory for the store is created, if necessary.) This property is optional since there are legitimate error conditions that could cause the creation of the store to fail.
        let fileManager = NSFileManager.defaultManager()
        var shouldFail = false
        var error: NSError? = nil
        var failureReason = "There was an error creating or loading the application's saved data."
        
        // Make sure the application files directory is there
        let propertiesOpt = self.applicationDocumentsDirectory.resourceValuesForKeys([NSURLIsDirectoryKey], error: &error)
        if let properties = propertiesOpt {
            if !properties[NSURLIsDirectoryKey]!.boolValue {
                failureReason = "Expected a folder to store application data, found a file \(self.applicationDocumentsDirectory.path)."
                shouldFail = true
            }
        } else if error!.code == NSFileReadNoSuchFileError {
            error = nil
            fileManager.createDirectoryAtPath(self.applicationDocumentsDirectory.path!, withIntermediateDirectories: true, attributes: nil, error: &error)
        }
        
        // Create the coordinator and store
        var coordinator: NSPersistentStoreCoordinator?
        if !shouldFail && (error == nil) {
            coordinator = NSPersistentStoreCoordinator(managedObjectModel: self.managedObjectModel)
            let url = self.applicationDocumentsDirectory.URLByAppendingPathComponent("SwiftPhotos.storedata")
            if coordinator!.addPersistentStoreWithType(NSXMLStoreType, configuration: nil, URL: url, options: nil, error: &error) == nil {
                coordinator = nil
            }
        }
        
        if shouldFail || (error != nil) {
            // Report any error we got.
            let dict = NSMutableDictionary()
            dict[NSLocalizedDescriptionKey] = "Failed to initialize the application's saved data"
            dict[NSLocalizedFailureReasonErrorKey] = failureReason
            if error != nil {
                dict[NSUnderlyingErrorKey] = error
            }
            error = NSError(domain: "YOUR_ERROR_DOMAIN", code: 9999, userInfo: dict)
            NSApplication.sharedApplication().presentError(error!)
            return nil
        } else {
            return coordinator
        }
        }()
    
    lazy var managedObjectContext: NSManagedObjectContext? = {
        // Returns the managed object context for the application (which is already bound to the persistent store coordinator for the application.) This property is optional since there are legitimate error conditions that could cause the creation of the context to fail.
        let coordinator = self.persistentStoreCoordinator
        if coordinator == nil {
            return nil
        }
        var managedObjectContext = NSManagedObjectContext()
        managedObjectContext.persistentStoreCoordinator = coordinator
        return managedObjectContext
        }()
    
    // MARK: - Core Data Saving and Undo support
    
    @IBAction func saveAction(sender: AnyObject!) {
        // Performs the save action for the application, which is to send the save: message to the application's managed object context. Any encountered errors are presented to the user.
        if let moc = self.managedObjectContext {
            if !moc.commitEditing() {
                NSLog("\(NSStringFromClass(self.dynamicType)) unable to commit editing before saving")
            }
            var error: NSError? = nil
            if moc.hasChanges && !moc.save(&error) {
                NSApplication.sharedApplication().presentError(error!)
            }
        }
    }
    
    func windowWillReturnUndoManager(window: NSWindow) -> NSUndoManager? {
        // Returns the NSUndoManager for the application. In this case, the manager returned is that of the managed object context for the application.
        if let moc = self.managedObjectContext {
            return moc.undoManager
        } else {
            return nil
        }
    }
    
    func applicationShouldTerminate(sender: NSApplication) -> NSApplicationTerminateReply {
        // Save changes in the application's managed object context before the application terminates.
        
        if let moc = managedObjectContext {
            if !moc.commitEditing() {
                NSLog("\(NSStringFromClass(self.dynamicType)) unable to commit editing to terminate")
                return .TerminateCancel
            }
            
            if !moc.hasChanges {
                return .TerminateNow
            }
            
            var error: NSError? = nil
            if !moc.save(&error) {
                // Customize this code block to include application-specific recovery steps.
                let result = sender.presentError(error!)
                if (result) {
                    return .TerminateCancel
                }
                
                let question = NSLocalizedString("Could not save changes while quitting. Quit anyway?", comment: "Quit without saves error question message")
                let info = NSLocalizedString("Quitting now will lose any changes you have made since the last successful save", comment: "Quit without saves error question info");
                let quitButton = NSLocalizedString("Quit anyway", comment: "Quit anyway button title")
                let cancelButton = NSLocalizedString("Cancel", comment: "Cancel button title")
                let alert = NSAlert()
                alert.messageText = question
                alert.informativeText = info
                alert.addButtonWithTitle(quitButton)
                alert.addButtonWithTitle(cancelButton)
                
                let answer = alert.runModal()
                if answer == NSAlertFirstButtonReturn {
                    return .TerminateCancel
                }
            }
        }
        // If we got here, it is time to quit.
        return .TerminateNow
    }
}

