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
    
    @IBOutlet weak var window: NSWindow!
    @IBOutlet weak var mImageBrowser: IKImageBrowserView!
    
    var mImages: [Photo] = []
    var mImportedImages: [Photo] = []
    
    override func awakeFromNib() {
        mImages = [Photo]()
        mImportedImages = [Photo]()
    }
    
    func updateDatasource() {
        //mImages.addObjectsFromArray(mImportedImages)
        //mImportedImages.removeAllObjects
        mImageBrowser.reloadData()
    }
    
    override func numberOfItemsInImageBrowser(aBrowser: IKImageBrowserView!) -> Int {
        return mImages.count
    }
    
    override func imageBrowser(aBrowser: IKImageBrowserView!, itemAtIndex index: Int) -> AnyObject! {
        return mImages[index]
    }
}