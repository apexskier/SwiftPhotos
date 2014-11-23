//
//  Library.swift
//  SwiftHelloWorldMac
//
//  Created by Cameron Little on 8/24/14.
//  Copyright (c) 2014 Daniel Bergquist. All rights reserved.
//

import Foundation
import CoreData

class Library: NSManagedObject {

    @NSManaged var photos: NSSet
    @NSManaged var settings: NSManagedObject

}
