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
    
    var mImages: [Photo] {
        get {
            return appDelegate.photos
        }
    }
    var mImportedImages: [Photo] = []
    
    override func viewDidLoad() {
        mImageBrowser.setDataSource(self)
        mImageBrowser.reloadData()
        
        NSNotificationCenter.defaultCenter().addObserverForName("newPhotos", object: nil, queue: nil, usingBlock: { (notification: NSNotification!) in
            self.mImageBrowser.reloadData()
        })
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
}