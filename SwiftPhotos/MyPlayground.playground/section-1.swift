// Playground - noun: a place where people can play

import Cocoa
import AppKit

var str = "Hello, playground"

var img = NSImage

func imageToGreyImage(image: NSImage) -> NSImage {
    var actualWidth = image.size.width
    var actualHeight = image.size.height
    
    var imageRect = CGRectMake(0, 0, actualWidth, actualHeight)
    var colorSpace = CGColorSpaceCreateDeviceGray()
    
    var context = CGBitmapContextCreate(nil, UInt(actualWidth), UInt(actualHeight), 8, 0, colorSpace, CGBitmapInfo(CGImageAlphaInfo.None.rawValue)) //CGBitmapInfo(CGImageAlphaInfo.None))
    CGContextDrawImage(context, imageRect, image.CGImage)
    
    var greyImage = CGBitmapContextCreateImage(context)
    
    context = CGBitmapContextCreate(nil, UInt(actualWidth), UInt(actualHeight), 8, 0, nil, CGBitmapInfo(CGImageAlphaInfo.Only.rawValue))
    CGContextDrawImage(context, imageRect, image.CGImage)
    var mask = CGBitmapContextCreateImage(context)
    
    var finalImage = CGImageCreateWithMask(greyImage, mask)
    return NSImage(CGImage: finalImage, size: NSSize(32, 32))
}