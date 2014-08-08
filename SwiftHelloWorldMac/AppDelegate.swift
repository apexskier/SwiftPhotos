//
//  AppDelegate.swift
//  SwiftHelloWorldMac
//
//  Created by Daniel Bergquist on 6/3/14.
//  Copyright (c) 2014 Daniel Bergquist. All rights reserved.
//

import Cocoa

class AppDelegate: NSObject, NSApplicationDelegate {
                            
    @IBOutlet var window: NSWindow!

    @IBOutlet var name : NSTextField!
    @IBOutlet var outputField : NSTextField!

    func applicationDidFinishLaunching(aNotification: NSNotification?) {
        // Insert code here to initialize your application
        self.outputField.stringValue = "Hello, World!"
    }

    func applicationWillTerminate(aNotification: NSNotification?) {
        // Insert code here to tear down your application
    }


    @IBAction func buttonPushed(sender : AnyObject) {
        var name = self.name.stringValue
        
        if name.isEmpty {
            self.outputField.stringValue = "Come again?"
        }
        else {
            let photo = Photo(path: self.name.stringValue)
            self.outputField.stringValue = "Getting, \(self.name.stringValue)!"
            
            if photo.valid {
                self.outputField.stringValue = "Got \(self.name.stringValue)\n"
                if let height = photo.height {
                    self.outputField.stringValue = self.outputField.stringValue + "Size \(photo.width!)x\(height)"
                }
            } else {
                self.outputField.stringValue = "Failed to get \(self.name.stringValue)"
            }
        }
    }
}

