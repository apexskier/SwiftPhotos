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

class ImageBrowserWindowController: NSViewController {
    
    private var appDelegate = NSApplication.sharedApplication().delegate as AppDelegate
    
    //@IBOutlet weak var window: NSWindow!
    @IBOutlet weak var mImageBrowser: IKImageBrowserView!
    @IBOutlet weak var imageSizeSlider: NSSlider!
    @IBOutlet weak var progressIndicator: NSProgressIndicator!
    @IBOutlet weak var photoLabel: NSTextField!
    @IBOutlet weak var photoInfoText: NSTextField!
    @IBOutlet weak var showInFinderButton: NSButton!
    @IBOutlet weak var similarButton: NSButton!
    @IBOutlet weak var similarityThreshold: NSSlider!
    
    @IBAction func zoomSliderChanged(sender: AnyObject) {
        mImageBrowser.setZoomValue(sender.floatValue)
        mImageBrowser.needsDisplay = true
    }
    
    var dateFormatter: NSDateFormatter = {
        var df = NSDateFormatter()
        df.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return df
    }()
    
    var selectedPhoto: Photo?
    
    var imagesFilter: (Photo -> Bool)?
    
    var mImages: [Photo] {
        get {
            if let filter = imagesFilter {
                return appDelegate.photos.filter(filter)
            } else {
                return appDelegate.photos
            }
        }
    }
    var mImportedImages: [Photo] = []
    
    var observers: [AnyObject] = []
    
    override func viewDidLoad() {
        photoLabel.stringValue = ""
        
        mImageBrowser.setDataSource(self)
        mImageBrowser.setDelegate(self)
        mImageBrowser.reloadData()
    }
    override func viewDidAppear() {
        mImageBrowser.reloadData()
        observers.append(NSNotificationCenter.defaultCenter().addObserverForName("newPhotos", object: nil, queue: nil, usingBlock: { (notification: NSNotification!) in
            self.mImageBrowser.reloadData()
            self.imageBrowserSelectionDidChange(nil)
        }))
        observers.append(NSNotificationCenter.defaultCenter().addObserverForName("startedTask", object: nil, queue: nil, usingBlock: { (notification: NSNotification!) in
            self.updateProgress()
        }))
    }
    override func viewDidDisappear() {
        for observer in observers {
            NSNotificationCenter.defaultCenter().removeObserver(observer)
        }
    }
    
    @IBAction func showInFinder(sender: AnyObject) {
        let selections = mImageBrowser.selectionIndexes()
        let urls = [mImages[selections.firstIndex].fileURL]
        NSWorkspace.sharedWorkspace().activateFileViewerSelectingURLs(urls)
    }
    
    @IBAction func similarSliderChange(sender: AnyObject) {
        showSimilar(sender)
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
        updateDatasource()
    }
    
    func updateProgress() {
        var discLeft: Double = Double(TaskManager.sharedManager.pendingDiscoveries.queue.operationCount)
        
        var hashLeft: Double = Double(TaskManager.sharedManager.pendingHashes.queue.operationCount)
        
        if discLeft + hashLeft == 0 {
            progressIndicator.stopAnimation(self)
        } else {
            progressIndicator.startAnimation(self)
        }
    }
    
    func updateDatasource() {
        mImageBrowser.reloadData()
    }
    
    override func numberOfItemsInImageBrowser(aBrowser: IKImageBrowserView!) -> Int {
        return mImages.count
    }
    
    override func imageBrowser(aBrowser: IKImageBrowserView!, itemAtIndex index: Int) -> AnyObject! {
        return mImages[index]
    }
    
    override func imageBrowserSelectionDidChange(aBrowser: IKImageBrowserView!) {
        let selections = mImageBrowser.selectionIndexes()
        if selections.count == 1 {
            selectedPhoto = mImages[selections.firstIndex]
            photoLabel.stringValue = selectedPhoto!.fileURL.lastPathComponent!
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
            }
            showInFinderButton.enabled = true
            similarButton.enabled = true
        } else {
            showInFinderButton.enabled = false
            similarButton.enabled = false
            photoLabel.stringValue = ""
            photoInfoText.stringValue = ""
            
            imagesFilter = nil
            updateDatasource()
        }
    }
}