//
//  Settings.swift
//  SwiftPhotos
//
//  Created by Cameron Little on 11/25/14.
//  Copyright (c) 2014 Cameron Little. All rights reserved.
//

import Foundation
import CoreData

class Settings: NSManagedObject {

    @NSManaged var zoom: Float
    @NSManaged var imports: NSMutableOrderedSet
    @NSManaged var output: Folder?
    @NSManaged var library: Library?

}

extension Settings {
    func appendImport(folder: Folder) {
        var imports = self.mutableOrderedSetValueForKey("imports")
        imports.addObject(folder)
    }
}