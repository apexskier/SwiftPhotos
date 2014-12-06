//
//  Photos.swift
//  PhotoManagement
//
//  Created by Cameron Little on 8/7/14.
//  Copyright (c) 2014 Cameron Little. All rights reserved.
//
/*
import Foundation
import CoreFoundation
import AppKit

enum PhotoState {
    case New, Known, Modified, Deleted, Broken
}

class Photo {
    // class var dateFormatter: NSDateFormatter = {
    //     let df = NSDateFormatter()
    //     df.dateFormat = "%Y:%m:%d %H:%i:%s"
    //     return df
    // }()
    
    var fileURL: NSURL = NSURL()
    var created: NSDate = NSDate()
    var state: PhotoState = PhotoState.New
    var height: NSNumber?
    var width: NSNumber?
    
    lazy var hash: UInt64 = {
        return phash(self.getImage())
    }()
    
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
            
            height = dictionary.objectForKey("PixelHeight") as NSNumber!
            width = dictionary.objectForKey("PixelWidth") as NSNumber!
            
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
            state = .Broken
        }
    }
    
    init(path: String) {
        let filemanager = NSFileManager.defaultManager()
        if !filemanager.fileExistsAtPath(path) {
            // Handle this
            println("File doesn't exist: \(path)")
            state = .Broken
        } else {
            println("File exists: \(path)")
            fileURL = NSURL(fileURLWithPath: path)! //   NSURL(string: path) as CFURLRef
            readData()
        }
    }
    
    init(url: NSURL) {
        fileURL = url
        readData()
    }
}*/