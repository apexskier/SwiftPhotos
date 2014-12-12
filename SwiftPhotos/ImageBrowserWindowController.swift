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
    
    @IBOutlet weak var discoverProgressIndicator: NSProgressIndicator!
    @IBOutlet weak var hashProgressIndicator: NSProgressIndicator!
    
    @IBOutlet weak var photoLabel: NSTextField!
    @IBOutlet weak var photoInfoText: NSTextField!
    @IBOutlet weak var similarButton: NSButton!
    
    @IBAction func zoomSliderChanged(sender: AnyObject) {
        mImageBrowser.setZoomValue(sender.floatValue)
        mImageBrowser.needsDisplay = true
    }
    
    var dateFormatter: NSDateFormatter = {
        var df = NSDateFormatter()
        df.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return df
    }()
    
    var mImages: [Photo] {
        get {
            return appDelegate.photos
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
    
    func updateProgress() {
        var discLeft: Double = Double(TaskManager.sharedManager.pendingDiscoveries.queue.operationCount)
        if discLeft == 0 {
            discoverProgressIndicator.maxValue = 1
            discoverProgressIndicator.stopAnimation(self)
        } else {
            discoverProgressIndicator.startAnimation(self)
        }
        if discoverProgressIndicator.maxValue < discLeft {
            discoverProgressIndicator.maxValue = discLeft
        }
        discoverProgressIndicator.doubleValue = discLeft
        
        var hashLeft: Double = Double(TaskManager.sharedManager.pendingHashes.queue.operationCount)
        if hashLeft == 0 {
            hashProgressIndicator.maxValue = 1
            hashProgressIndicator.stopAnimation(self)
        } else {
            hashProgressIndicator.startAnimation(self)
        }
        if hashProgressIndicator.maxValue < hashLeft {
            hashProgressIndicator.maxValue = hashLeft
        }
        hashProgressIndicator.doubleValue = hashLeft
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
            let photo = mImages[selections.firstIndex]
            photoLabel.stringValue = photo.fileURL.lastPathComponent!
            photoInfoText.stringValue = "file key: "
            if let hash = photo.fhash {
                photoInfoText.stringValue += "\(hash)\n"
            } else {
                photoInfoText.stringValue += "incomplete\n"
            }
            photoInfoText.stringValue += "file hash: "
            if let hash = photo.phash {
                photoInfoText.stringValue += "\(hash)\n"
            } else {
                photoInfoText.stringValue += "incomplete\n"
            }
            if let created = photo.created {
                photoInfoText.stringValue += "\n\(dateFormatter.stringFromDate(created))\n"
            }
        } else {
            photoLabel.stringValue = ""
            photoInfoText.stringValue = ""
        }
    }
}