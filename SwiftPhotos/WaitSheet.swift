//
//  WaitSheet.swift
//  SwiftPhotos
//
//  Created by Cameron Little on 12/14/14.
//  Copyright (c) 2014 Cameron Little. All rights reserved.
//

import AppKit
import Foundation

class WaitSheetController: NSWindowController {
    
    override init() {
        super.init(window: nil)
        
        /* Load window from xib file */
        NSBundle.mainBundle().loadNibNamed("WaitSheet", owner: self, topLevelObjects: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    @IBOutlet var theWindow: WaitSheet!
    
}

class WaitSheet: NSWindow {
    
    @IBOutlet weak var titleText: NSTextField!
    @IBOutlet weak var contentText: NSTextField!
    
}