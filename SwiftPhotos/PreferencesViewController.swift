//
//  PreferencesViewController.swift
//  SwiftPhotos
//
//  Created by Cameron Little on 12/5/14.
//  Copyright (c) 2014 Cameron Little. All rights reserved.
//

import Foundation

import Cocoa


class PreferencesViewController: NSViewController, NSTableViewDataSource, NSTableViewDelegate {
    
    private var inputs = [Folder]()
    
    @IBOutlet weak var tableView: NSTableView!
    @IBOutlet weak var removeImportButton: NSButton!
    
    /// Managed object context for the view controller (which is bound to the persistent store coordinator for the application).
    private lazy var managedObjectContext: NSManagedObjectContext = {
        let moc = NSManagedObjectContext(concurrencyType: .MainQueueConcurrencyType)
        moc.persistentStoreCoordinator = CoreDataStackManager.sharedManager.persistentStoreCoordinator
        return moc
    }()
    
    private lazy var taskContext: NSManagedObjectContext = {
        var anyError: NSError?
        
        let taskContext = privateQueueContext(&anyError)
        if taskContext == nil {
            println("Error creating fetching context: \(anyError)")
            fatalError("Couldn't create fetching context.")
        }
        
        return taskContext
    }()
    
    @IBAction func addImportSourceClick(sender: AnyObject) {
        var filePicker = NSOpenPanel()
        filePicker.canChooseDirectories = true
        filePicker.canChooseFiles = false
        filePicker.allowsMultipleSelection = true
        
        var result = filePicker.runModal()
        
        if result == NSOKButton {
            for url in filePicker.URLs as [NSURL] {
                var folder: Folder = NSEntityDescription.insertNewObjectForEntityForName("Folder", inManagedObjectContext: taskContext) as Folder
                folder.path = url.absoluteString!
                inputs.append(folder)
                println("Adding import source: \(folder.path)")
            }
            
            var anyError: NSError?
            if !taskContext.save(&anyError) {
                println("Error saving batch: \(anyError)")
                fatalError("Saving batch failed.")
                return
            }
            taskContext.reset()
            
            self.reloadTableView(nil)
            
            filePicker.close()
        }
    }
    
    @IBAction func removeImportSourceClick(sender: AnyObject) {
        var idxs = tableView.selectedRowIndexes
        
        idxs.enumerateRangesWithOptions(NSEnumerationOptions.Reverse, { (range: NSRange, stop: UnsafeMutablePointer<ObjCBool>) in
            let location = range.location
            let length = range.length
            for var i = (location + length - 1); i >= location; i-- {
                if i != -1 {
                    self.taskContext.deleteObject(self.inputs[i])
                    self.inputs.removeAtIndex(i)
                }
            }
        })
        
        var anyError: NSError?
        if !self.taskContext.save(&anyError) {
            println("Error saving batch: \(anyError)")
            fatalError("Saving batch failed.")
            return
        }
        self.taskContext.reset()
        
        reloadTableView(self)
    }
    
    // MARK: View Life Cycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.setDataSource(self)
        reloadTableView(self)
    }
    
    /// Fetch Folders in settings object and display.
    private func reloadTableView(sender: AnyObject?) {
        let request = NSFetchRequest(entityName: "Folder")
        
        var anyError: NSError?
        
        let fetchedSources = taskContext.executeFetchRequest(request, error:&anyError)
        
        if fetchedSources == nil {
            println("Error fetching: \(anyError)")
            fatalError("Fetch failed.")
            return
        }
        
        inputs = fetchedSources as [Folder]
        
        tableView.reloadData()
    }
    
    // MARK: NSTableViewDataSource
    
    func numberOfRowsInTableView(tableView: NSTableView) -> Int {
        if inputs.count <= 0 {
            removeImportButton.enabled = false
        } else {
            removeImportButton.enabled = true
        }
        return inputs.count
    }
    
    // MARK: NSTableViewDelegate
    
    func tableView(tableView: NSTableView, objectValueForTableColumn tableColumn: NSTableColumn?, row: Int) -> AnyObject? {
        let relativePath = NSURL(string: inputs[row].path)?.relativeString
        return NSString(string: relativePath!).stringByReplacingPercentEscapesUsingEncoding(NSUTF8StringEncoding)
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