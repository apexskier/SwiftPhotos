//
//  Photo.swift
//  SwiftPhotos
//
//  Created by Cameron Little on 11/25/14.
//  Copyright (c) 2014 Cameron Little. All rights reserved.
//

import AppKit
import CoreData
import Foundation

enum PhotoState: Int16 {
    case New = 0
    case Known = 1
    case Modified = 2
    case Deleted = 3
    case Broken = 4
}

class Photo: NSManagedObject {

    @NSManaged var filename: String
    @NSManaged var phash: UInt64
    @NSManaged var ahash: UInt64
    @NSManaged var fhash: UInt64
    @NSManaged var state: Int16
    @NSManaged var created: NSDate
    @NSManaged var filepath: String
    
    @NSManaged var height: Int
    @NSManaged var width: Int
    
    var stateEnum: PhotoState {
        get {
            return PhotoState(rawValue: self.state) ?? PhotoState.New
        }
        set {
            self.state = Int16(newValue.rawValue)
        }
    }
    
    lazy var fileURL: NSURL = {
        let filemanager = NSFileManager.defaultManager()
        if !filemanager.fileExistsAtPath(self.filepath) {
            // Handle this
            println("File doesn't exist: \(self.filepath)")
            self.stateEnum = .Broken
        }
        return NSURL(fileURLWithPath: self.filepath)!
    }()
    
    func genPhash() {
        phash = calcPhash(self.getImage())
    }
    
    func move(newpath: String) {
        // TODO: implement
    }
    
    func updateExif() {
        // TODO: get exif info from self
    }
    
    func getImage() -> NSImage {
        return NSImage(byReferencingURL: fileURL)
    }
    
    func CGImageSource() -> CGImageSourceRef {
        return CGImageSourceCreateWithURL(fileURL, nil)
    }
    
    func readData() {
        let imageSource = CGImageSourceCreateWithURL(fileURL, nil)
        
        var index: UInt = 0
        let imageProperties = CGImageSourceCopyPropertiesAtIndex(imageSource, index, NSDictionary())
        
        if imageProperties != nil {
            var dictionary = imageProperties as NSDictionary
            
            height = Int(dictionary.objectForKey("PixelHeight") as NSNumber!)
            width = Int(dictionary.objectForKey("PixelWidth") as NSNumber!)
            
            var exifTree = dictionary.objectForKey("{Exif}") as [String: NSObject]?
            if let eT = exifTree {
                var dateFormatter = NSDateFormatter()
                dateFormatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
                
                if let exifDateTimeOriginal = eT["DateTimeOriginal"] {
                    created = dateFormatter.dateFromString(exifDateTimeOriginal as String) as NSDate!
                }
                
                for (key, value) in eT {
                    println(key)
                }
            }
        } else {
            stateEnum = .Broken
        }
    }
    
/*
    init(path: String, managedObjectContext: NSManagedObjectContext) {
        let myEntity: NSString = "Photo"
        if let entity = NSEntityDescription.entityForName(myEntity, inManagedObjectContext: managedObjectContext) {
            super.init(entity: entity, insertIntoManagedObjectContext: managedObjectContext)

            let filemanager = NSFileManager.defaultManager()
            if filemanager.fileExistsAtPath(path) {
                println("File exists: \(path)")
                fileURL = NSURL(fileURLWithPath: path)! //   NSURL(string: path) as CFURLRef
                readData()
                return
            }
            stateEnum = .Broken
        } else {
            var error: NSError?
            NSException.raise("Exception", format:"Error: %@", arguments:getVaList([error ?? "nil"]))
            super.init()
        }
    }
    
    
    
    init(url: NSURL, managedObjectContext: NSManagedObjectContext) {
        let myEntity: NSString = NSString(string: "Photo")
        var entity = NSEntityDescription.entityForName(myEntity, inManagedObjectContext: managedObjectContext)
        if entity == nil {
            entity = NSEntityDescription.insertNewObjectForEntityForName(myEntity, inManagedObjectContext: managedObjectContext) as NSEntityDescription
        }
        if entity != nil {
            super.init(entity: entity!, insertIntoManagedObjectContext: managedObjectContext)
            fileURL = url
            return
        } else {
            NSException.raise("Exception", format:"Error: Couldn't load entity '\(myEntity)'", arguments:getVaList([]))
            super.init()
        }
    }
*/    
}