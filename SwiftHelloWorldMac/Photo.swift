//
//  Photos.swift
//  PhotoManagement
//
//  Created by Cameron Little on 8/7/14.
//  Copyright (c) 2014 Cameron Little. All rights reserved.
//

import Foundation
import CoreFoundation
import AppKit

class Photo {
    var path: String
    var created: NSDate
    var valid: Bool
    var height: NSNumber?
    var width: NSNumber?
    var image: NSImage?
    
    func move(newpath: String) {
        // TODO: implement
        
        path = newpath
    }
    
    func getExif() {
        // TODO: get exif infor from self
    }
    
    init(path: String) {
        valid = false
        let filemanager = NSFileManager.defaultManager()
        if !filemanager.fileExistsAtPath(path) {
            // Handle this
            NSLog("File doesn't exist: \(path)")
        } else {
            NSLog("File exists: \(path)")
            
            let imageFileURL = NSURL(fileURLWithPath: path) //   NSURL(string: path) as CFURLRef
            let imageSource = CGImageSourceCreateWithURL(imageFileURL, nil).takeRetainedValue()
            let options = [kCGImageSourceShouldCache: false] as NSDictionary
            
            var index: UInt = 0
            let imageProperties = CGImageSourceCopyPropertiesAtIndex(imageSource, index, options).takeRetainedValue()
            
            if imageProperties != nil {
                
                var dictionary = imageProperties.__conversion()
                
                //var treeDict = NSDictionary(objectsAndKeys: imageProperties) //NSDictionary(objectsAndKeys: imageProperties as )
                
                height = dictionary.objectForKey("PixelHeight") as NSNumber!
                width = dictionary.objectForKey("PixelWidth") as NSNumber!
                
                var exifTree = dictionary.objectForKey("Exif") as NSDictionary!
                
                var data = "height: \(height)\nwidth: \(width)\n"
                
                if exifTree != nil {
                    for key in exifTree.allKeys as [NSString] {
                        var locKey = NSBundle(identifier: "com.apple.ImageIO.framework").localizedStringForKey(key, value: key, table: "CGImageSource")
                        var value = exifTree.valueForKey(key) as NSString!
                        data += "\(key): \(value)\n"
                    }
                }
                
                image = NSImage(byReferencingURL: imageFileURL)
                
                NSLog(data)
                
                valid = true
            }
        }
        
        self.path = path
        created = NSDate()
    }
}

// /Users/cameronlittle/Downloads/test.jpg


/*
NSURL *imageFileURL = [NSURL fileURLWithPath:@"/Users/USERNAME/Documents/tasting_menu_004.jpg"];
CGImageSourceRef imageSource = CGImageSourceCreateWithURL((CFURLRef)imageFileURL, NULL);
NSDictionary *treeDict;
NSMutableString *exifData;

NSDictionary *options = [NSDictionary dictionaryWithObjectsAndKeys:
                        [NSNumber numberWithBool:NO], (NSString *)kCGImageSourceShouldCache, nil];

CFDictionaryRef imageProperties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, (CFDictionaryRef)options);
CFRelease(imageSource);
if (imageProperties) {
    treeDict = [NSDictionary dictionaryWithDictionary:(NSDictionary*)(imageProperties)];
    id exifTree = [treeDict objectForKey:@"{Exif}"];

    exifData = [NSMutableString stringWithString:@""];

    for (NSString *key in [[exifTree allKeys] sortedArrayUsingSelector:@selector(compare:)]) {
        NSString* locKey = [[NSBundle bundleWithIdentifier:@"com.apple.ImageIO.framework"] localizedStringForKey:key value:key table: @"CGImageSource"];
        id value = [exifTree  valueForKey:key];
        [exifData appendFormat:@"key =%@ ; Value = %@ \n", locKey,value];

    }
    NSLog(@" exifData %@", exifData);
*/