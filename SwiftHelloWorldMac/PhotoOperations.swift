//
//  PhotoOperations.swift
//  SwiftHelloWorldMac
//
//  Created by Cameron Little on 11/23/14.
//  Copyright (c) 2014 Cameron Little. All rights reserved.
//

import Foundation

// http://www.raywenderlich.com/76341/use-nsoperation-nsoperationqueue-swift
class PhotoOperations {
    lazy var hashesInProgress = [NSURL:NSOperation]()
    lazy var hashesQueue: NSOperationQueue = {
        var q = NSOperationQueue()
        q.name = "Hashes Queue"
        q.maxConcurrentOperationCount = 1 // TODO: remove this line
        return q
    }()
}

class PhotoHasher: NSOperation {
    let photo: Photo
    
    init(photo: Photo) {
        self.photo = photo
    }
    
    override func main() {
        autoreleasepool {
            println("Started hashing \(self.photo.fileURL)")
            if self.cancelled {
                println("Cancelled hashing \(self.photo.fileURL)")
                return
            }
            
            let ph = self.photo.hash
            self.photo.state = .Known
            println("Done hashing \(self.photo.fileURL)")
        }
    }
}