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
import Quartz

enum PhotoState: Int16 {
    case New = 0
    case Known = 1
    case Modified = 2
    case Deleted = 3
    case Broken = 4
}

class Photo: NSManagedObject/*, IKImageBrowserItem*/ {

    @NSManaged var phash: NSNumber?
    @NSManaged var ahash: NSNumber?
    @NSManaged var fhash: NSNumber?
    @NSManaged var state: Int16
    @NSManaged var created: NSDate?
    @NSManaged var filepath: String
    
    @NSManaged var height: NSNumber?
    @NSManaged var width: NSNumber?
    
    var stateEnum: PhotoState {
        get {
            return PhotoState(rawValue: self.state) ?? PhotoState.New
        }
        set {
            self.state = Int16(newValue.rawValue)
        }
    }
    
    lazy var fileURL: NSURL = {
        if let url = NSURL(string: self.filepath) {
            return url
        } else {
            // Handle this
            println("File doesn't exist: \(self.filepath)")
            self.stateEnum = .Broken
            return NSURL()
        }
    }()
    
    func genPhash() {
        phash = NSNumber(unsignedLongLong: calcPhash(self.getImage()))
        println("set phash")
        stateEnum = .Known
    }
    
    func genFhash() {
        let data: NSMutableData = NSMutableData(contentsOfFile: fileURL.relativePath!)!
        var md5: MD5 = MD5()
        var hash = NSNumber(unsignedLongLong: CRCHash(data))
        if hash != fhash {
            stateEnum = .New
        }
        fhash = hash
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
            }
        } else {
            stateEnum = .Broken
        }
    }
        
    func setPath(path: String) {
        if filepath != path {
            filepath = path
        }
    }
    
    override func imageRepresentationType() -> String {
        return IKImageBrowserNSURLRepresentationType
    }
    
    override func imageRepresentation() -> AnyObject {
        return fileURL
    }
    
    override func imageUID() -> String {
        return filepath
    }
}
