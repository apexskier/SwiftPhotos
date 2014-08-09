//
//  AppDelegate.swift
//  SwiftPhotos
//
//  Created by Cameron Little.
//

import Cocoa

class AppDelegate: NSObject, NSApplicationDelegate {
    
    @IBOutlet var window: NSWindow!
    
    @IBOutlet var outputField : NSTextField!
    @IBOutlet var imageView: NSImageView!
    
    func applicationDidFinishLaunching(aNotification: NSNotification?) {
        // Insert code here to initialize your application
        self.outputField.stringValue = "Hello, World!"
        // self.filePicker.canChooseFiles = true
        // self.filePicker.canChooseDirectories = true
        //self.filePicker.allowsMultipleSelection = true
        
        // println(self.filePicker.URLs)
    }
    
    func applicationWillTerminate(aNotification: NSNotification?) {
        // Insert code here to tear down your application
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
                displayImage(Photo(url: firstURL))
            }
            filePicker.close()
        } else if result == NSCancelButton {
            println("Cancel Clicked")
        }
    }
    
    func displayImage(photo: Photo) {
        self.outputField.stringValue = "Getting photo!"
        
        if photo.valid {
            self.outputField.stringValue = "Got \(photo.fileURL.description)\n"
            if let height = photo.height {
                self.outputField.stringValue = self.outputField.stringValue + "Size: \(photo.width!)x\(height)"
            }
            self.outputField.stringValue = self.outputField.stringValue + "\nDate: \(photo.created.description)"
            imageView.image = photo.getImage()
        } else {
            self.outputField.stringValue = "Failed to get photo 😞."
        }
    }
}

