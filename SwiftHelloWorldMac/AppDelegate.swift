//
//  AppDelegate.swift
//  SwiftPhotos
//
//  Created by Cameron Little.
//

import Cocoa
import CoreData

class AppDelegate: NSObject, NSApplicationDelegate {
    
    @IBOutlet var window: NSWindow!
    
    @IBOutlet var importArrayController: NSArrayController!
    @IBOutlet var outputTextField: NSTextField!
    
    @IBOutlet var tableView: NSTableView!
    @IBOutlet var outputField : NSTextField!
    @IBOutlet var imageView: NSImageView!
    

    
    var storeURL = NSURL(fileURLWithPath: "~/.photos")
    
    var inputs = pathArray()
    
    func applicationDidFinishLaunching(aNotification: NSNotification?) {
        // Insert code here to initialize your application
        
        self.outputField.stringValue = "Hello, World!"
        
    
        tableView.setDataSource(inputs)
    }
    
    func applicationWillTerminate(aNotification: NSNotification?) {
        // Insert code here to tear down your application
    }
    
    @IBAction func chooseOutputClick(sender: NSButton) {
        var filePicker = NSOpenPanel()
        filePicker.canChooseDirectories = true
        filePicker.canChooseFiles = false
        filePicker.allowsMultipleSelection = false
        
        var result = filePicker.runModal()
        
        if result == NSOKButton {
            println("OK Clicked")
            var outputPath = filePicker.URL!
            outputTextField.stringValue = outputPath.relativePath!
            println(outputPath.relativePath)
            filePicker.close()
        } else if result == NSCancelButton {
            println("Cancel Clicked")
        }
    }
    @IBAction func addImportSourceClick(sender: AnyObject) {
        var filePicker = NSOpenPanel()
        filePicker.canChooseDirectories = true
        filePicker.canChooseFiles = false
        filePicker.allowsMultipleSelection = true
        
        var result = filePicker.runModal()
        
        if result == NSOKButton {
            println("OK Clicked")
            for url in filePicker.URLs as [NSURL] {
                inputs.append(url)
                println(url.description)
            }
            tableView.reloadData()
            filePicker.close()
        } else if result == NSCancelButton {
            println("Cancel Clicked")
        }
    }
    @IBAction func removeImportSourceClick(sender: NSButtonCell) {
        var idx = tableView.selectedRow
        if idx != -1 {
            inputs.removeAt(idx)
        }
        tableView.reloadData()
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
            var image = photo.getImage()
            self.outputField.stringValue += "\nphash: \(phash(image))"
            imageView.image = imageToGreyImage(image)
        } else {
            self.outputField.stringValue = "Failed to get photo 😞."
        }
    }
}

