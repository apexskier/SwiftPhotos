//
//  PhotoHashingUtils.swift
//  SwiftHelloWorldMac
//
//  Created by Cameron Little on 11/22/14.
//  Copyright (c) 2014 Cameron Little. All rights reserved.
//
//  Some utilities for computing photo similarity hashes and comparing them.
//  TODO: use Surge or something to make math faster

import Foundation
import AppKit
import CoreFoundation


// Add "field" to NSImage to get CGImage
// http://stackoverflow.com/questions/24595908/swift-nsimage-to-cgimage
extension NSImage {
    var CGImage: CGImageRef {
        get {
            let imageData = self.TIFFRepresentation
            var source = CGImageSourceCreateWithData(imageData, nil)
            return CGImageSourceCreateImageAtIndex(source, UInt(0), nil)
        }
    }
    
    /*//http://stackoverflow.com/questions/25146557/how-do-i-get-the-color-of-a-pixel-in-a-uiimage-with-swift
    func pixelColor(point: CGPoint) -> UIColor {
        var pixelData = CGDataProviderCopyData(CGImageGetDataProvider(self.CGImage))
        var data: UnsafePointer<UInt8> = CFDataGetBytePtr(pixelData)
        
        var pixelInfo: Int = ((Int(self.size.width) * Int(point.y)) + Int(point.x)) * 4
        
        var r = CGFloat(data[pixelInfo]) / CGFloat(255.0)
        var g = CGFloat(data[pixelInfo+1]) / CGFloat(255.0)
        var b = CGFloat(data[pixelInfo+2]) / CGFloat(255.0)
        var a = CGFloat(data[pixelInfo+3]) / CGFloat(255.0)
        
        return UIColor(red: r, green: g, blue: b, alpha: a)
    }*/
}


func avghash(image: NSImage) -> UInt64 {
    // 1. Reduce size to 8x8.
    // 2. Reduce to grayscale.
    var workingImage = imageToGreyImage(image, CGSize(width: 8, height: 8))
    
    var imageColors = [[Double]](count: 8, repeatedValue: [Double](count: 8, repeatedValue: 0.0))
    
    // Get array of pixel data of working image
    var pixelData = CGDataProviderCopyData(CGImageGetDataProvider(workingImage.CGImage))
    var data: UnsafePointer<UInt8> = CFDataGetBytePtr(pixelData)
    
    // 3. Average the colors
    var avg = 0.0
    for i in 0...7 {
        for j in 0...7 {
            var pixelPos: Int = (8 * i + j) * 4
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
    
    return hash
}

func phash(image: NSImage) -> UInt64 {
    // http://www.hackerfactor.com/blog/?/archives/432-Looks-Like-It.html
    
    /// 1. Reduce size to 32x32. (reduce high frequencies)
    /// 2. Reduce to grayscale.
    var workingImage = imageToGreyImage(image, CGSize(width: 32, height: 32))

    /// 3. Compute the DCT (discrete cosine transform.
    var imageDTC = dtc(workingImage)
    
    /// 4. Reduce the DCT.
    /*var reducedDTC = [[Double]](count: 8, repeatedValue: [Double](count: 8, repeatedValue: Double(0.0)))
    for i in 0...7 {
        for j in 0...7 {
            reducedDTC[i][j] = imageDTC[i][j]
        }
    }*/
    
    /// 5. Compute the average value of a reduced DTC (upper left 8x8).
    var avg = 0.0
    for i in 0...7 {
        for j in 0...7 {
            if !(i == 0 && j == 0) {
                avg += imageDTC[i][j]
            }
        }
    }
    avg /= 63

    /// 6. Calculate a 64 bit hash by comparing the DTC values to the avg.
    /// 7. Construct the hash. Set the 64 bits into a 64-bit integer.
    var hash: UInt64 = 0
    for i in 0...7 {
        for j in 0...7 {
            if imageDTC[i][j] < avg {
                hash |= 1
            }
            if !(j == 7 && i == 7) {
                hash <<= 1
            }
        }
    }
    
    return hash
}

let SQRT2o2 = 1.414213562373095048801688724209 * 0.5 // ? * 0.5
func alpha(i: Int) -> Double {
    if i == 0 {
        return SQRT2o2
    }
    return 0.5
}
let inv16 = 1.0 / 16.0
let cosine = { () -> [[Double]] in
    var arr = [[Double]](count: 32, repeatedValue: [Double](count: 32, repeatedValue: Double(0.0)))
    for i in 0...31 {
        for j in 0...31 {
            arr[j][i] = cos(M_PI * Double(j) * (2.0 + Double(i) + 1.0) * inv16)
        }
    }
    return arr
}()
func dtc(image: NSImage) -> [[Double]] {
    var A = [[Double]](count: 32, repeatedValue: [Double](count: 32, repeatedValue: 0.0))
    
    // Get array of pixel data of working image
    var pixelData = CGDataProviderCopyData(CGImageGetDataProvider(image.CGImage))
    var data: UnsafePointer<UInt8> = CFDataGetBytePtr(pixelData)
    
    for y in 0...31 { // image size is 32x32
        for x in 0...31 {
            A[y][x] = 0
            var pixelPos: Int = (8 * x + y) * 4
            var color = Double(data[pixelPos]) / 255.0
            for u in 0...31 {
                for v in 0...31 {
                    A[y][x] += alpha(u) * alpha(v) * color * cosine[u][x] * cosine[v][y]
                }
            }
        }
    }
    return A
}

func hammingDistance(a: UInt64, b: UInt64) -> Int {
    // Number of different bits between a and b
    var n = a ^ b
    var c = 0
    // https://graphics.stanford.edu/~seander/bithacks.html#CountBitsSetKernighan
    while n != 0 {
        n &= n - 1
        c++
    }
    return c
}

func imageToGreyImage(image: NSImage, size: CGSize) -> NSImage {
    var width = image.size.width
    var height = image.size.height
    
    var imageRect = CGRectMake(0, 0, CGFloat(width), CGFloat(height))
    var colorSpace = CGColorSpaceCreateDeviceGray()
    
    var context = CGBitmapContextCreate(nil, UInt(width), UInt(height), 8, 0, colorSpace, CGBitmapInfo(CGImageAlphaInfo.None.rawValue))
    CGContextDrawImage(context, imageRect, image.CGImage)
    
    var greyImage = CGBitmapContextCreateImage(context)
    
    context = CGBitmapContextCreate(nil, UInt(width), UInt(height), 8, 0, nil, CGBitmapInfo(CGImageAlphaInfo.Only.rawValue))
    CGContextDrawImage(context, imageRect, image.CGImage)
    var mask = CGBitmapContextCreateImage(context)
    
    var finalImage = CGImageCreateWithMask(greyImage, mask)
    return NSImage(CGImage: finalImage, size: NSSize(width: size.width, height: size.height))
}