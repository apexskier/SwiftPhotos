//
//  PhotoHashingUtils.swift
//  SwiftPhotos
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

func calcAvghash(image: NSImage) -> UInt64 {
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

func calcPhash(image: NSImage) -> UInt64 {
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

private let SQRT2o2 = 1.414213562373095048801688724209 * 0.5 // ? * 0.5
private func alpha(i: Int) -> Double {
    if i == 0 {
        return SQRT2o2
    }
    return 0.5
}
private let inv16 = 1.0 / 16.0
private let cosine = { () -> [[Double]] in
    var arr = [[Double]](count: 32, repeatedValue: [Double](count: 32, repeatedValue: Double(0.0)))
    for i in 0...31 {
        for j in 0...31 {
            arr[j][i] = cos(M_PI * Double(j) * (2.0 + Double(i) + 1.0) * inv16)
        }
    }
    return arr
}()
private func dtc(image: NSImage) -> [[Double]] {
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

private func imageToGreyImage(image: NSImage, size: CGSize) -> NSImage {
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


/// MARK: MD5 hash

// Note: All variables are unsigned 32 bit and wrap modulo 2^32 when calculating


class MD5 {
    // s specifies the per-round shift amounts
    // let s: [UInt32][64]
    private var s: [UInt32] = [7, 12, 17, 22,  7, 12, 17, 22,  7, 12, 17, 22,  7, 12, 17, 22,
        5,  9, 14, 20,  5,  9, 14, 20,  5,  9, 14, 20,  5,  9, 14, 20,
        4, 11, 16, 23,  4, 11, 16, 23,  4, 11, 16, 23,  4, 11, 16, 23,
        6, 10, 15, 21,  6, 10, 15, 21,  6, 10, 15, 21,  6, 10, 15, 21]
    
    // let K: [UInt32][64]
    private var K: [UInt32] = [0xd76aa478, 0xe8c7b756, 0x242070db, 0xc1bdceee,
        0xf57c0faf, 0x4787c62a, 0xa8304613, 0xfd469501,
        0x698098d8, 0x8b44f7af, 0xffff5bb1, 0x895cd7be,
        0x6b901122, 0xfd987193, 0xa679438e, 0x49b40821,
        0xf61e2562, 0xc040b340, 0x265e5a51, 0xe9b6c7aa,
        0xd62f105d, 0x02441453, 0xd8a1e681, 0xe7d3fbc8,
        0x21e1cde6, 0xc33707d6, 0xf4d50d87, 0x455a14ed,
        0xa9e3e905, 0xfcefa3f8, 0x676f02d9, 0x8d2a4c8a,
        0xfffa3942, 0x8771f681, 0x6d9d6122, 0xfde5380c,
        0xa4beea44, 0x4bdecfa9, 0xf6bb4b60, 0xbebfbc70,
        0x289b7ec6, 0xeaa127fa, 0xd4ef3085, 0x04881d05,
        0xd9d4d039, 0xe6db99e5, 0x1fa27cf8, 0xc4ac5665,
        0xf4292244, 0x432aff97, 0xab9423a7, 0xfc93a039,
        0x655b59c3, 0x8f0ccc92, 0xffeff47d, 0x85845dd1,
        0x6fa87e4f, 0xfe2ce6e0, 0xa3014314, 0x4e0811a1,
        0xf7537e82, 0xbd3af235, 0x2ad7d2bb, 0xeb86d391]
    // Use binary integer part of the sines of integers (Radians) as constants:
    /*let K: [UInt32] = {
    var K: [UInt32] = [UInt32](count: 64, repeatedValue: 0)
    for i in 0...63 {
    var val = floor(abs(sin(Float(i) + 1)) * (2.0 % 32.0))
    K[i] = UInt32(val)
    }
    return K
    }()*/
    
    func OldHash(data: NSMutableData) -> String {
        // Initialize variables
        var a0: UInt32 = 0x67452301 // A
        var b0: UInt32 = 0xefcdab89 // B
        var c0: UInt32 = 0x98badcfe // C
        var d0: UInt32 = 0x10325476 // D
        
        let origLength: Int64 = Int64(data.length) * 4
        
        // Pre-processing: adding a single 1 bit
        var oneZeros: Int8 = 0x08
        var zeroByte: Int8 = 0x00
        data.appendBytes(&oneZeros, length: 1)
        
        /* Notice: the input bytes are considered as bits strings,
        where the first bit is the most significant bit of the byte. */
        
        // Pre-processing: padding with zeros
        // append "0" bit until message length in bits ≡ 448 (mod 512)
        while data.length % 128 != 120 {
            data.appendBytes(&zeroByte, length: 1)
        }
        // append original length in bits mod (2 pow 64) to message
        var lenPart: UInt64 = UInt64(origLength) % UINT64_MAX
        data.appendBytes(&lenPart, length: 8)
        
        // Process the message in successive 512-bit chunks
        for var chunkBoundary = 0; chunkBoundary < data.length; chunkBoundary += 128 {
            var chunk = data.subdataWithRange(NSRange(location: chunkBoundary, length: 128))
            
            // break chunk into sixteen 32-bit words
            var M: [UInt32] = [UInt32](count: 16, repeatedValue: 0)
            chunk.getBytes(&M, length: sizeof(UInt32) * 16)
            
            // Initialize hash value for this chunk:
            var A: UInt32 = a0
            var B: UInt32 = b0
            var C: UInt32 = c0
            var D: UInt32 = d0
            var F: UInt32 = 0
            var G: UInt32 = 0
            // Main loop:
            for i: UInt32 in 0...63 {
                if (0 <= i) && (i <= 15) {
                    F = (B & C) | ((~B) & D)
                    G = i
                } else if (16 <= i) && (i <= 31) {
                    F = (D & B) | ((~D) & C)
                    G = (5 * i + 1) % 16
                } else if (32 <= i) && (i <= 47) {
                    F = B ^ C ^ D
                    G = (3 * i + 5) % 16
                } else if (48 <= i) && (i <= 63) {
                    F = C ^ (B | (~D))
                    G = (7 * i) % 16
                }
                var dTemp = D
                D = C
                C = B
                //B = B + leftrotate(A + F + K[Int(i)] + M[Int(G)], s[Int(i)])
                var x = (A &+ F &+ K[Int(i)] &+ M[Int(G)])
                var c = s[Int(i)]
                var lr = (x << c) | (x >> (32 - c))
                B = B &+ lr
                A = dTemp
            }
            //Add this chunk's hash to result so far:
            a0 = a0 &+ A
            b0 = b0 &+ B
            c0 = c0 &+ C
            d0 = d0 &+ D
        }
        
        var intArrDigest: [UInt32] = [a0, b0, c0, d0]
        // var digest: [char][16]
        var dataDigest = NSMutableData(bytes: &intArrDigest, length: 16)
        /*var charDigest: [Character] = [Character](count: 16, repeatedValue: "\0")
        dataDigest.getBytes(&charDigest, length: 16)
        for char in charDigest {
            print(char)
            println()
        }*/
        // var uint64Digest: UInt64 = 0
        // dataDigest.getBytes(&uint64Digest, length: 8)
        
        return dataDigest.base64EncodedStringWithOptions(nil)
    }
    
    private class func leftrotate (x: UInt32, c: UInt32) -> UInt32 {
        return (x << c) | (x >> (32 - c));
    }
}



func CRCHash(data: NSMutableData) -> UInt64 {
    // Variation of CRC32
    let poly: UInt64 = 0x67452301
    var shiftReg: UInt64 = 0
    for i in 1...(data.length - 1) {
        var chunk = data.subdataWithRange(NSRange(location: i, length: 1))
        
        // break chunk into sixteen 32-bit words
        var c: UInt8 = 0
        chunk.getBytes(&c, length: sizeof(UInt8))
        
        if (c & 8) != 0 {
            shiftReg = (shiftReg << 1) ^ 0x67452301
        } else {
            shiftReg = (shiftReg << 1)
        }
    }
    return shiftReg
}
