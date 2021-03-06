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
    
    var fileURL: NSURL {
        get {
            if let url = NSURL(string: self.filepath) {
                return url
            }
            self.stateEnum = .Broken
            return NSURL()
        }
        set(newURL) {
            self.filepath = newURL.absoluteString!
        }
    }
    
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
        
        if let image = createCGImage(fileURL) {
            // 1. Reduce size to 8x8.
            // 2. Reduce to grayscale.
            let scaledImage = resizeImageToGray(image, 8, 8)
            
            var imageColors = [[Double]](count: 8, repeatedValue: [Double](count: 8, repeatedValue: 0.0))
            
            // Get array of pixel data of working image
            var pixelData = CGDataProviderCopyData(CGImageGetDataProvider(scaledImage))
            var data: UnsafePointer<UInt8> = CFDataGetBytePtr(pixelData)
            var bytesPerRow = Int(CGImageGetBytesPerRow(scaledImage))
            var bytesPerPixel = Int(CGImageGetBitsPerPixel(scaledImage)) / 8
            
            // 3. Average the colors
            var avg = 0.0
            for i in 0...7 {
                for j in 0...7 {
                    var pixelPos: Int = (bytesPerRow * i) + j * bytesPerPixel
                    var color = Double(data[pixelPos]) / 255.0
                    imageColors[i][j] = color
                    avg += color
                }
            }
            avg /= 64
            
            
            // 4. Compute the bits
            // 5. Construct the hash
            var hash: UInt64 = 0
            for i in 0...7 {
                for j in 0...7 {
                    if imageColors[i][j] < avg {
                        hash |= 1
                    }
                    if !(j == 7 && i == 7) {
                        hash <<= 1
                    }
                }
            }
            
            ahash = NSNumber(unsignedLongLong: hash)
        }
    }
    
    func genFhash() {
        if stateEnum == .Broken {
            return
        }
        
        if let path = fileURL.relativePath {
            if let data: NSMutableData = NSMutableData(contentsOfFile: path) {
                var md5: MD5 = MD5()
                var hash = NSNumber(unsignedLongLong: CRCHash(data))
                if fhash != nil && Int(hash) != Int(fhash!) {
                    reset()

                    // TODO: This may not be safe.
                    TaskManager.sharedManager.discoverPhoto(objectID)
                }
                fhash = hash
            }
        }
    }

    func reset() {
        stateEnum = .New

        phash = nil
        ahash = nil
        fhash = nil
        color = nil
        exposure = nil
        created = nil
        height = nil
        width = nil
    }

    func genQualityMeasures() {
        if stateEnum == .Broken {
            return
        }
        genExposure()
        // genColorRange()
    }
    
    func genExposure() {
        if stateEnum == .Broken {
            return
        }
        if exposure != nil {
            return
        }
        if let image = createCGImage(fileURL) {
            let sampleSize = 32
            let scaledImage = resizeImageToGray(image, sampleSize, sampleSize)
            
            // Get array of pixel data of working image
            var pixelData = CGDataProviderCopyData(CGImageGetDataProvider(scaledImage))
            var data: UnsafePointer<UInt8> = CFDataGetBytePtr(pixelData)
            var bytesPerRow = Int(CGImageGetBytesPerRow(scaledImage))
            var bytesPerPixel = Int(CGImageGetBitsPerPixel(scaledImage)) / 8
            
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

        if let imageProperties = CGImageSourceCopyPropertiesAtIndex(imageSource, index, NSDictionary()) {
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
            if created == nil {
                // TODO: Fallback to file creation date.
                // perhaps provide an interface to write file creation date to exif?
            }
        } else {
            stateEnum = .Broken
        }
    }
    
    /// KImageBrowserItem
    
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
