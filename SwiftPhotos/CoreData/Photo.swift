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
    
    @NSManaged var exposure: NSNumber?
    @NSManaged var colorRed: NSNumber?
    @NSManaged var colorGreen: NSNumber?
    @NSManaged var colorBlue: NSNumber?
    @NSManaged var color: NSNumber?
    
    @NSManaged var height: NSNumber?
    @NSManaged var width: NSNumber?

    @NSManaged var duplicates: NSMutableSet
    @NSManaged var library: Library?
    
    var stateEnum: PhotoState {
        get {
            if let path = fileURL.relativePath {
                if !NSFileManager.defaultManager().fileExistsAtPath(path) {
                    return .Broken
                }
            } else {
                return .Broken
            }
            return PhotoState(rawValue: self.state) ?? PhotoState.New
        }
        set {
            self.state = Int16(newValue.rawValue)
        }
    }
    
    lazy var fileURL: NSURL = {
        if let url = NSURL(string: self.filepath) {
            return url
        }
        // Handle this
        self.stateEnum = .Broken
        return NSURL()
    }()
    
    func genPhash() {
        if stateEnum == .Broken {
            return
        }
        if phash != nil {
            return
        }
        phash = NSNumber(unsignedLongLong: calcPhash(self.getImage()))
    }

    func genAhash() {
        if stateEnum == .Broken {
            return
        }
        if ahash != nil {
            return
        }
        ahash = NSNumber(unsignedLongLong: calcAvghash(self.fileURL))
    }
    
    func genFhash() {
        var url = fileURL
        if stateEnum == .Broken {
            return
        }
        if let path = fileURL.relativePath {
            if let data: NSMutableData = NSMutableData(contentsOfFile: path) {
                var md5: MD5 = MD5()
                var hash = NSNumber(unsignedLongLong: CRCHash(data))
                if hash != fhash {
                    stateEnum = .New
                    phash = nil
                    color = nil
                    exposure = nil
                }
                fhash = hash
            }
        }
    }
    
    func genQualityMeasures() {
        if stateEnum == .Broken {
            return
        }
        genExposure()
        genColorRange()
    }
    func genExposure() {
        if stateEnum == .Broken {
            return
        }
        if exposure != nil {
            return
        }
        let sampleSize = 128
        
        let scaledImage = scaleImage(getImage(), CGSize(width: sampleSize, height: sampleSize))
        
        //http://stackoverflow.com/questions/25146557/how-do-i-get-the-color-of-a-pixel-in-a-uiimage-with-swift
        
        var pixelData = CGDataProviderCopyData(CGImageGetDataProvider(scaledImage.CGImage))
        var data: UnsafePointer<UInt8> = CFDataGetBytePtr(pixelData)
        
        var exposureHistogram: [Double] = [Double](count: 256, repeatedValue: 0.0)
            
        for x in 0...(sampleSize - 1) {
            for y in 0...(sampleSize - 1) {
                var pixelInfo: Int = ((128 * x) + y) * 4
                
                var r: Double = Double(data[pixelInfo])
                var g: Double = Double(data[pixelInfo+1])
                var b: Double = Double(data[pixelInfo+2])
                var intensity = Int(floor((r + g + b) / 3.0))
                
                exposureHistogram[intensity]++
            }
        }
        
        var max: Double = 0
        var min: Double = 128 * 128
        for i in 7...247 { // trim high and low 8 to reduce frequency
            if exposureHistogram[i] < min {
                min = exposureHistogram[i]
            } else if exposureHistogram[i] > max {
                max = exposureHistogram[i]
            }
        }
        
        // sampleSize^2 points distributed over 256 slots
        // exactly even would be 64 in each slot
        var offset: Double = 0
        for i in 0...255 {
            offset += abs(exposureHistogram[i] - 64)
        }
        exposure = offset
    }
    func genColorRange() {
        if stateEnum == .Broken {
            return
        }
        if color != nil {
            return
        }
        let sampleSize = 128
        
        let scaledImage = scaleImage(getImage(), CGSize(width: sampleSize, height: sampleSize))
        
        //http://stackoverflow.com/questions/25146557/how-do-i-get-the-color-of-a-pixel-in-a-uiimage-with-swift
        
        var pixelData = CGDataProviderCopyData(CGImageGetDataProvider(scaledImage.CGImage))
        var data: UnsafePointer<UInt8> = CFDataGetBytePtr(pixelData)
        
        var histogramRed = [Double](count: 256, repeatedValue: 0.0)
        var histogramGreen = [Double](count: 256, repeatedValue: 0.0)
        var histogramBlue = [Double](count: 256, repeatedValue: 0.0)
        
        for x in 0...(sampleSize - 1) {
            for y in 0...(sampleSize - 1) {
                var pixelInfo: Int = ((128 * x) + y) * 4
                
                var r = Int(data[pixelInfo])
                var g = Int(data[pixelInfo+1])
                var b = Int(data[pixelInfo+2])
                
                histogramRed[r]++
                histogramGreen[g]++
                histogramBlue[b]++
            }
        }
        
        var maxRed: Double = 0
        var minRed: Double = 128 * 128
        var maxGreen: Double = 0
        var minGreen: Double = 128 * 128
        var maxBlue: Double = 0
        var minBlue: Double = 128 * 128
        for i in 0...255 {
            if histogramRed[i] < minRed {
                minRed = histogramRed[i]
            } else if histogramRed[i] > maxRed {
                maxRed = histogramRed[i]
            }
            if histogramGreen[i] < minGreen {
                minGreen = histogramGreen[i]
            } else if histogramGreen[i] > maxGreen {
                maxGreen = histogramGreen[i]
            }
            if histogramBlue[i] < minBlue {
                minBlue = histogramBlue[i]
            } else if histogramBlue[i] > maxBlue {
                maxBlue = histogramBlue[i]
            }
        }
        
        // sampleSize^2 points distributed over 256 slots
        // exactly even would be 64 in each slot
        
        // Small is better
        var diversityRed = maxRed - minRed
        var diversityGreen = maxGreen - minGreen
        var diversityBlue = maxBlue - minBlue
        color = NSNumber(double: diversityRed + diversityGreen + diversityBlue)
        /*
        // Higher means more of that color
        (colorRed, colorGreen, colorBlue) = {
            var r: Double = 0
            var g: Double = 0
            var b: Double = 0
            for i in 1...255 {
                var di = Double(i)
                r += di * histogramRed[i]
                g += di * histogramGreen[i]
                b += di * histogramBlue[i]
            }
            
            var m = max(r, g, b)
            var double_max = Double(UINT64_MAX)
            return (UInt64((r * double_max) / m),
                    UInt64((g * double_max) / m),
                    UInt64((b * double_max) / m))
        }()*/
    }
    
    func move(newpath: String) {
        if stateEnum == .Broken {
            return
        }
        // TODO: implement
    }
    
    func updateExif() {
        if stateEnum == .Broken {
            return
        }
        // TODO: get exif info from self
    }
    
    func getImage() -> NSImage {
        return NSImage(byReferencingURL: fileURL)
    }
    
    func CGImageSource() -> CGImageSourceRef {
        return CGImageSourceCreateWithURL(fileURL, nil)
    }
    
    func readData() {
        if stateEnum == .Broken {
            return
        }
        if created != nil {
            return
        }
        let imageSource = CGImageSourceCreateWithURL(fileURL, nil)
        
        var index: UInt = 0
        let imageProperties = CGImageSourceCopyPropertiesAtIndex(imageSource, index, NSDictionary())
        
        if imageProperties != nil {
            var dictionary = imageProperties as NSDictionary
            
            if let h: AnyObject = dictionary.objectForKey("PixelHeight") {
                height = h as? NSNumber
            }
            if let w: AnyObject = dictionary.objectForKey("PixelWidth") {
                width = w as? NSNumber
            }
            
            var exifTree = dictionary.objectForKey("{Exif}") as [String: NSObject]?
            if let eT = exifTree {
                var dateFormatter = NSDateFormatter()
                dateFormatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
                
                if let date = eT["DateTimeOriginal"] {
                    created = dateFormatter.dateFromString(date as String) as NSDate!
                } else if let date = eT["DateTimeDigitized"] {
                    created = dateFormatter.dateFromString(date as String) as NSDate!
                }
            }
        } else {
            stateEnum = .Broken
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
