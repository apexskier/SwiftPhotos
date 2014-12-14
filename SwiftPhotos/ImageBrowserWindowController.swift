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

class ImageBrowserViewController: NSViewController {
    
    private var appDelegate = NSApplication.sharedApplication().delegate as AppDelegate
    
    //@IBOutlet weak var window: NSWindow!
    @IBOutlet weak var imageBrowser: IKImageBrowserView!
    
    @IBOutlet weak var countTextField: NSTextField!
    @IBOutlet weak var progressIndicator: NSProgressIndicator!
    
    @IBOutlet weak var imageSizeSlider: NSSlider!
    @IBOutlet weak var showInFinderButton: NSButton!
    @IBOutlet weak var removeButton: NSButton!
    @IBOutlet weak var similarButton: NSButton!
    @IBOutlet weak var similarityThreshold: NSSlider!
    @IBOutlet weak var onlyHashedCheckbox: NSButton!
    @IBOutlet weak var orderSelectBox: NSPopUpButtonCell!
    
    @IBAction func zoomSliderChanged(sender: AnyObject) {
        imageBrowser.setZoomValue(sender.floatValue)
        imageBrowser.needsDisplay = true
    }
    
    var dateFormatter: NSDateFormatter = {
        var df = NSDateFormatter()
        df.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return df
    }()
    
    var selectedPhoto: Photo?
    
    var imagesFilter: (Photo -> Bool)?
    
    var images: [Photo] = []
    
    var filterOperation: FilterOperation?
    
    var observers: [AnyObject] = []
    
    override func viewDidLoad() {
        imageBrowser.setCanControlQuickLookPanel(false)
        
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
        observers.append(NSNotificationCenter.defaultCenter().addObserverForName("startedTask", object: nil, queue: nil, usingBlock: { (notification: NSNotification!) in
            self.updateProgress()
        }))
        observers.append(NSNotificationCenter.defaultCenter().addObserverForName("updatePhotos", object: nil, queue: NSOperationQueue.mainQueue(), usingBlock: { (notification: NSNotification!) in
            self.imageBrowser.reloadData()
            self.countTextField.stringValue = "\(self.images.count)/\(self.appDelegate.photos.count)"
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
            selections.enumerateIndexesUsingBlock({ (i: Int, stop: UnsafeMutablePointer<ObjCBool>) in
                var photo = self.images[i]
                self.appDelegate.deletePhoto(photo, error: &error)
                if error != nil {
                    println("Failed to remove file: \(error)")
                    stop.initialize(true)
                }
                
                self.images.removeAtIndex(i)
            })
            updateImages()
        }
    }
    
    @IBAction func similarSliderChange(sender: AnyObject) {
        showSimilar(sender)
    }
    @IBAction func showOnlyHashedChange(sender: AnyObject) {
        updateImages()
    }
    @IBAction func showSimilar(sender: AnyObject) {
        var state = similarButton.state
        if state == 1 {
            if let Ahash = selectedPhoto!.phash {
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
        } else {
            imagesFilter = nil
        }
        updateImages()
    }
    
    @IBAction func orderButtonChange(sender: AnyObject) {
        let selectButton = sender as NSPopUpButton
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
        }
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
    
    var order = { (p1: Photo, p2: Photo) -> Bool in
        if let c1 = p1.created {
            if let c2 = p2.created {
                return c1.compare(c2) == NSComparisonResult.OrderedDescending
            }
        }
        return true
    }

    func updateImages() {
        if let filterOp = filterOperation {
            filterOp.cancel()
        }
        filterOperation = FilterOperation({
            self.progressIndicator.startAnimation(self)
            
            var photos: [Photo]
            if let filter = self.imagesFilter {
                photos = self.appDelegate.photos.filter(filter)
            } else {
                photos = self.appDelegate.photos
            }
            photos = sorted(photos, self.order).filter({ (photo: Photo) -> Bool in
                if self.onlyHashedCheckbox.state == 1 {
                    if let phash = photo.phash {
                        // pass
                    } else {
                        return false
                    }
                }
                return true
            })
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
        if selections.count > 0 {
            if selections.count == 1 {
                //selectedPhoto = images[selections.firstIndex]
                /*photoLabel.stringValue = selectedPhoto!.fileURL.lastPathComponent!
                photoInfoText.stringValue = "file key: "
                if let hash = selectedPhoto!.fhash {
                    photoInfoText.stringValue += "\(hash)\n"
                } else {
                    photoInfoText.stringValue += "incomplete\n"
                }
                photoInfoText.stringValue += "file hash: "
                if let hash = selectedPhoto!.phash {
                    photoInfoText.stringValue += "\(hash)\n"
                } else {
                    photoInfoText.stringValue += "incomplete\n"
                }
                if let created = selectedPhoto!.created {
                    photoInfoText.stringValue += "\n\(dateFormatter.stringFromDate(created))\n"
                }*/
                showInFinderButton.enabled = true
                similarButton.enabled = true
            } else {
                showInFinderButton.enabled = false
                similarButton.enabled = false
            }
            removeButton.enabled = true
        } else {
            showInFinderButton.enabled = false
            similarButton.enabled = false
            removeButton.enabled = false
        }
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