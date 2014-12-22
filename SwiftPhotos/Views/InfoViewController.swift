//
//  InfoViewController.swift
//  SwiftPhotos
//
//  Created by Cameron Little on 12/13/14.
//  Copyright (c) 2014 Cameron Little. All rights reserved.
//

import Foundation
import AppKit

class InfoViewController: NSViewController {
    
    var appDelegate = NSApplication.sharedApplication().delegate as AppDelegate
    
    var observers: [AnyObject] = []
    
    @IBOutlet weak var imageTitle: NSTextField!
    @IBOutlet weak var textArea: NSTextField!
    
    var selectedPhoto: Photo? {
        get {
            return appDelegate.selectedPhoto
        }
    }
    
    var dateFormatter: NSDateFormatter = {
        var df = NSDateFormatter()
        df.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return df
    }()
    
    func openInFinder(sender: AnyObject) {
        if let photo = self.selectedPhoto {
            NSWorkspace.sharedWorkspace().activateFileViewerSelectingURLs([photo.fileURL])
        }
    }
    
    override func viewDidDisappear() {
        for observer in observers {
            NSNotificationCenter.defaultCenter().removeObserver(observer)
        }
    }
    
    override func viewWillAppear() {
        observers.append(NSNotificationCenter.defaultCenter().addObserverForName("selectionChanged", object: nil, queue: nil, usingBlock: { (notification: NSNotification!) in
            
            self.updateContents()
        }))
        updateContents()
        super.viewWillAppear()
    }
    
    func updateContents() {
        imageTitle.stringValue = ""
        textArea.stringValue = ""
        
        if let photo = self.selectedPhoto {
            if let text = photo.fileURL.lastPathComponent {
                imageTitle.stringValue = text
            }
            
            if let created = photo.created {
                textArea.stringValue += "\(dateFormatter.stringFromDate(created))\n\n"
            }
            textArea.stringValue += "fhash: "
            if let hash = photo.fhash {
                textArea.stringValue += "\(hash)"
            }
            textArea.stringValue += "\n"
            textArea.stringValue += "phash: "
            if let hash = photo.phash {
                textArea.stringValue += "\(hash)"
            }
            textArea.stringValue += "\n"
            textArea.stringValue += "ahash: "
            if let hash = photo.ahash {
                textArea.stringValue += "\(hash)"
            }
            textArea.stringValue += "\n\n"
            textArea.stringValue += "exposure: "
            if let hash = photo.exposure {
                textArea.stringValue += "\(hash)"
            }
            textArea.stringValue += "\n"
            textArea.stringValue += "color: "
            if let hash = photo.color {
                textArea.stringValue += "\(hash)"
            }
            textArea.stringValue += "\n"
            textArea.stringValue += "colorRed: "
            if let hash = photo.colorRed {
                textArea.stringValue += "\(hash)"
            }
            textArea.stringValue += "\n"
            textArea.stringValue += "colorGreen: "
            if let hash = photo.colorGreen {
                textArea.stringValue += "\(hash)"
            }
            textArea.stringValue += "\n"
            textArea.stringValue += "colorBlue: "
            if let hash = photo.colorBlue {
                textArea.stringValue += "\(hash)"
            }
            textArea.stringValue += "\n\n"
            
            textArea.stringValue += "state: "
            switch photo.stateEnum {
            case .New:
                textArea.stringValue += "New\n"
            case .Known:
                textArea.stringValue += "Known\n"
            case .Modified:
                textArea.stringValue += "Modified\n"
            case .Deleted:
                textArea.stringValue += "Deleted\n"
            case .Broken:
                textArea.stringValue += "Broken\n"
            default:
                textArea.stringValue += "Unknown\n"
            }
            textArea.stringValue += "\n"
            
            textArea.stringValue += "path: "
            textArea.stringValue += photo.filepath
        }
    }
    
}