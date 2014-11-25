//
//  Library.swift
//  SwiftPhotos
//
//  Created by Cameron Little on 8/24/14.
//  Copyright (c) 2014 Cameron Little. All rights reserved.
//

import Foundation
import CoreData

class Library: NSManagedObject {

    @NSManaged var photos: NSSet
    @NSManaged var settings: NSManagedObject

}
