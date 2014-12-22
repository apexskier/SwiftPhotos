//
//  ImageBrowserWindowController.swift
//  SwiftPhotos
//
//  Created by Cameron Little on 12/9/14.
//  Copyright (c) 2014 Cameron Little. All rights reserved.
//

import Foundation
import AppKit
import Quartz

class MainViewController: NSViewController {
    
    private var appDelegate = NSApplication.sharedApplication().delegate as AppDelegate
    
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
    
    private var photos: [Photo] {
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
    
    @IBOutlet weak var imageBrowser: IKImageBrowserView!
    
    @IBOutlet weak var countTextField: NSTextField!
    @IBOutlet weak var progressIndicator: NSProgressIndicator!
    
    @IBOutlet weak var imageSizeSlider: NSSlider!
    @IBOutlet weak var showInFinderButton: NSButton!
    @IBOutlet weak var removeButton: NSButton!
    @IBOutlet weak var infoButton: NSButton!
    @IBOutlet weak var similarityThreshold: NSSlider!
    @IBOutlet weak var onlyKnownCheckbox: NSButton!
    @IBOutlet weak var onlyBrokenCheckbox: NSButton!
    @IBOutlet weak var orderSelectBox: NSPopUpButton!
    
    @IBOutlet weak var psimCheck: NSButton!
    @IBOutlet weak var fsimCheck: NSButton!
    @IBOutlet weak var asimCheck: NSButton!
    
    @IBOutlet weak var dupsCheck: NSButton!
    
    @IBAction func zoomSliderChanged(sender: AnyObject) {
        imageBrowser.setZoomValue(sender.floatValue)
        imageBrowser.needsDisplay = true
        
        settings.zoom = sender.floatValue
        
        var anyError: NSError?
        if !managedObjectContext.save(&anyError) {
            fatalError("Error saving: \(anyError)")
        }
    }
    
    var selectedPhoto: Photo? {
        get {
            return appDelegate.selectedPhoto
        }
    }
    
    var imagesFilter: (Photo -> Bool)?
    
    var images: [Photo] = []
    
    var filterOperation: FilterOperation?
    
    var observers: [AnyObject] = []
    
    override func viewDidLoad() {
        imageBrowser.setCanControlQuickLookPanel(false)
        
        imageSizeSlider.floatValue = settings.zoom
        imageBrowser.setZoomValue(imageSizeSlider.floatValue)
        
        orderSelectBox.selectItemAtIndex(0)
        
        imageBrowser.setDataSource(self)
        imageBrowser.setDelegate(self)
        self.progressIndicator.stopAnimation(self)
    }
    override func viewDidAppear() {
        imageBrowser.setCanControlQuickLookPanel(true)
        
        observers.append(NSNotificationCenter.defaultCenter().addObserverForName("newPhotos", object: nil, queue: nil, usingBlock: { (notification: NSNotification!) in
            self.updateImages()
            self.imageBrowserSelectionDidChange(nil)
        }))
        observers.append(NSNotificationCenter.defaultCenter().addObserverForName("completedTask", object: nil, queue: nil, usingBlock: { (notification: NSNotification!) in
            self.updateProgress()
        }))
        observers.append(NSNotificationCenter.defaultCenter().addObserverForName("updatePhotos", object: nil, queue: NSOperationQueue.mainQueue(), usingBlock: { (notification: NSNotification!) in
            self.imageBrowser.reloadData()
            self.countTextField.stringValue = "\(self.images.count)/\(self.photos.count)"
            self.progressIndicator.stopAnimation(self)
        }))
        
        updateImages()
    }
    override func viewDidDisappear() {
        for observer in observers {
            NSNotificationCenter.defaultCenter().removeObserver(observer)
        }
    }
    
    @IBAction func showInFinder(sender: AnyObject) {
        let selections = imageBrowser.selectionIndexes()
        let urls = [images[selections.firstIndex].fileURL]
        NSWorkspace.sharedWorkspace().activateFileViewerSelectingURLs(urls)
    }
    
    @IBAction func removeButtonPushed(sender: AnyObject) {
        let selections = imageBrowser.selectionIndexes()
        if selections.count == 0 {
            return
        }
        
        var areYouSure: NSAlert = NSAlert()
        areYouSure.addButtonWithTitle("OK")
        areYouSure.addButtonWithTitle("Cancel")
        if selections.count == 1 {
            areYouSure.messageText = "Delete this file?"
        } else {
            areYouSure.messageText = "Delete these files?"
        }
        areYouSure.informativeText = "Deleted files cannot be recovered."
        areYouSure.alertStyle = NSAlertStyle.WarningAlertStyle
        
        if areYouSure.runModal() == NSAlertFirstButtonReturn {
            // OK clicked, delete files
            var error: NSError?
            selections.enumerateRangesWithOptions(NSEnumerationOptions.Reverse, { (range: NSRange, stop: UnsafeMutablePointer<ObjCBool>) in
                let location = range.location
                let length = range.length
                for var i = (location + length - 1); i >= location; i-- {
                    if i != -1 {
                        var photo = self.images[i]
                        self.appDelegate.deletePhoto(photo, error: &error)
                        if error != nil {
                            println("Failed to remove file: \(error)")
                            stop.initialize(true)
                        }
                        
                        self.images.removeAtIndex(i)
                    }
                }
            })
            
            updateImages()
        }
    }
    @IBAction func dupsCheckChanged(sender: AnyObject) {

        updateImages()
    }
    
    @IBAction func similarSliderChange(sender: AnyObject) {
        if asimCheck.state == 1 {
            showSimilarA(sender)
        } else {
            if fsimCheck.state == 1 {
                showSimilarF(sender)
            } else {
                if psimCheck.state == 1 {
                    showSimilarP(sender)
                }
            }
        }
    }
    @IBAction func showOnlyKnownChange(sender: AnyObject) {
        onlyBrokenCheckbox.state = 0
        updateImages()
    }
    @IBAction func showOnlyBrokenChange(sender: AnyObject) {
        onlyKnownCheckbox.state = 0
        updateImages()
    }
    @IBAction func showSimilarF(sender: AnyObject) {
        var state = fsimCheck.state
        if state == 1 {
            psimCheck.state = 0
            asimCheck.state = 0
            if let photo = selectedPhoto {
                if let Ahash = photo.fhash {
                    let ahash: UInt64 = Ahash.unsignedLongLongValue
                    self.imagesFilter = { (photo: Photo) -> Bool in
                        if let bhash = photo.fhash {
                            let dist = hammingDistance(ahash, bhash.unsignedLongLongValue)
                            if dist <= self.similarityThreshold.integerValue {
                                return true
                            }
                        }
                        return false
                    }
                }
            }
        } else {
            imagesFilter = nil
        }
        updateImages()
    }
    @IBAction func showSimilarP(sender: AnyObject) {
        var state = psimCheck.state
        if state == 1 {
            fsimCheck.state = 0
            asimCheck.state = 0
            if let photo = selectedPhoto {
                if let Ahash = photo.phash {
                    let ahash: UInt64 = Ahash.unsignedLongLongValue
                    self.imagesFilter = { (photo: Photo) -> Bool in
                        if let bhash = photo.phash {
                            let dist = hammingDistance(ahash, bhash.unsignedLongLongValue)
                            if dist <= self.similarityThreshold.integerValue {
                                return true
                            }
                        }
                        return false
                    }
                }
            }
        } else {
            imagesFilter = nil
        }
        updateImages()
    }
    @IBAction func showSimilarA(sender: AnyObject) {
        var state = asimCheck.state
        if state == 1 {
            fsimCheck.state = 0
            psimCheck.state = 0
            if let photo = selectedPhoto {
                if let Ahash = photo.ahash {
                    let ahash: UInt64 = Ahash.unsignedLongLongValue
                    self.imagesFilter = { (photo: Photo) -> Bool in
                        if let bhash = photo.ahash {
                            let dist = hammingDistance(ahash, bhash.unsignedLongLongValue)
                            if dist <= self.similarityThreshold.integerValue {
                                return true
                            }
                        }
                        return false
                    }
                }
            }
        } else {
            imagesFilter = nil
        }
        updateImages()
    }
    @IBAction func getInfoButtonPressed(sender: AnyObject) {
        NSNotificationCenter.defaultCenter().postNotificationName("getInfo", object: selectedPhoto)
        appDelegate.showInfoHUD()
    }


    
    @IBAction func orderButtonChange(sender: AnyObject) {
        /*let selectButton = sender as NSPopUpButton
        let selection = selectButton.indexOfSelectedItem
        switch selection {
        case 1:
            order = { (p1: Photo, p2: Photo) -> Bool in
                if let e1 = p1.exposure {
                    if let e2 = p2.exposure {
                        return Double(e1) < Double(e2)
                    }
                }
                return true
            }
        case 2:
            order = { (p1: Photo, p2: Photo) -> Bool in
                if let c1 = p1.color {
                    if let c2 = p2.color {
                        return Double(c1) < Double(c2)
                    }
                }
                return true
            }
        case 3:
            order = { (p1: Photo, p2: Photo) -> Bool in
                if let c1 = p1.colorRed {
                    if let c2 = p2.colorRed {
                        return Double(c1) > Double(c2)
                    }
                }
                return true
            }
        case 4:
            order = { (p1: Photo, p2: Photo) -> Bool in
                if let c1 = p1.colorGreen {
                    if let c2 = p2.colorGreen {
                        return Double(c1) > Double(c2)
                    }
                }
                return true
            }
        case 5:
            order = { (p1: Photo, p2: Photo) -> Bool in
                if let c1 = p1.colorBlue {
                    if let c2 = p2.colorBlue {
                        return Double(c1) > Double(c2)
                    }
                }
                return true
            }
        case 0:
            fallthrough
        default:
            order = { (p1: Photo, p2: Photo) -> Bool in
                if let c1 = p1.created {
                    if let c2 = p2.created {
                        return c1.compare(c2) == NSComparisonResult.OrderedDescending
                    }
                }
                return true
            }
        }*/
        updateImages()
    }
    
    func updateProgress() {
        /*var discLeft: Double = Double(TaskManager.sharedManager.pendingDiscoveries.queue.operationCount)
        
        var hashLeft: Double = Double(TaskManager.sharedManager.pendingHashes.queue.operationCount)
        
        if discLeft + hashLeft == 0 {
            progressIndicator.stopAnimation(self)
        } else {
            progressIndicator.startAnimation(self)
        }*/
    }
    
    /*var order: (p1: Photo, p2: Photo) -> Bool = { (p1: Photo, p2: Photo) -> Bool in
        if let c1 = p1.created {
            if let c2 = p2.created {
                return c1.compare(c2) == NSComparisonResult.OrderedDescending
            }
        }
        return true
    }*/
    func order(p1: Photo, p2: Photo) -> Bool {
        if dupsCheck.state == 1 {
            if let e1 = p1.ahash {
                if let e2 = p2.ahash {
                    return Double(e1) < Double(e2)
                }
            }
            return true
        }
        let selectButton = orderSelectBox
        let selection = selectButton.indexOfSelectedItem
        switch selection {
        case 1:
            if let e1 = p1.exposure {
                if let e2 = p2.exposure {
                    return Double(e1) < Double(e2)
                }
            }
            return true
        case 2:
            if let c1 = p1.color {
                if let c2 = p2.color {
                    return Double(c1) < Double(c2)
                }
            }
            return true
        case 3:
            if let c1 = p1.colorRed {
                if let c2 = p2.colorRed {
                    return Double(c1) > Double(c2)
                }
            }
            return true
        case 4:
            if let c1 = p1.colorGreen {
                if let c2 = p2.colorGreen {
                    return Double(c1) > Double(c2)
                }
            }
            return true
        case 5:
            if let c1 = p1.colorBlue {
                if let c2 = p2.colorBlue {
                    return Double(c1) > Double(c2)
                }
            }
            return true
        case 0:
            fallthrough
        default:
            if let c1 = p1.created {
                if let c2 = p2.created {
                    return c1.compare(c2) == NSComparisonResult.OrderedDescending
                }
            }
            return true
        }
    }

    func updateImages() {
        if let filterOp = filterOperation {
            filterOp.cancel()
        }
        filterOperation = FilterOperation({
            self.progressIndicator.startAnimation(self)
            
            var photos: [Photo]
            if let filter = self.imagesFilter {
                photos = self.photos.filter(filter)
            } else {
                photos = self.photos
            }
            photos = sorted(photos.filter({ (photo: Photo) -> Bool in
                if self.dupsCheck.state == 1 {
                    if photo.duplicates.count == 0 {
                        return false
                    }
                }
                if self.onlyKnownCheckbox.state == 1 {
                    if photo.stateEnum != .Known {
                        return false
                    }
                } else if self.onlyBrokenCheckbox.state == 1 {
                    if photo.stateEnum != .Broken {
                        return false
                    }
                }
                return true
            }), self.order)
            self.images = photos
        })
        filterOperation!.completionBlock = {
            NSNotificationCenter.defaultCenter().postNotificationName("updatePhotos", object: nil)
        }
        filterOperation!.start()
    }
    
    override func numberOfItemsInImageBrowser(aBrowser: IKImageBrowserView!) -> Int {
        return images.count
    }
    
    override func imageBrowser(aBrowser: IKImageBrowserView!, itemAtIndex index: Int) -> AnyObject! {
        return images[index]
    }
    
    override func imageBrowserSelectionDidChange(aBrowser: IKImageBrowserView!) {
        let selections = imageBrowser.selectionIndexes()
        appDelegate.selectedPhoto = nil
        showInFinderButton.enabled = false
        psimCheck.enabled = false
        fsimCheck.enabled = false
        asimCheck.enabled = false
        removeButton.enabled = false
        appDelegate.getInfoMenuItem.enabled = false
        infoButton.enabled = false
        if selections.count > 0 {
            if selections.count == 1 {
                appDelegate.selectedPhoto = images[selections.firstIndex]
                showInFinderButton.enabled = true
                psimCheck.enabled = true
                fsimCheck.enabled = true
                asimCheck.enabled = true
                appDelegate.getInfoMenuItem.enabled = true
                //infoButton.enabled = true
            }
            removeButton.enabled = true
        } else {
            psimCheck.state = 0
            fsimCheck.state = 0
            asimCheck.state = 0
            showSimilarF(fsimCheck)
        }
        NSNotificationCenter.defaultCenter().postNotificationName("selectionChanged", object: nil)
    }
}

class FilterOperation: NSOperation {
    let op: (() -> ())
    
    init(op: (() -> ())) {
        self.op = op
    }
    override func main() {
        autoreleasepool {
            if self.cancelled {
                return
            }
            self.op()
        }
    }
}