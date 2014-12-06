//
//  Library.swift
//  SwiftPhotos
//
//  Created by Cameron Little on 11/25/14.
//  Copyright (c) 2014 Cameron Little. All rights reserved.
//

import Foundation
import CoreData

class Library: NSManagedObject {

    @NSManaged var name: String
    @NSManaged var settings: Settings
    @NSManaged var photos: NSSet

}
