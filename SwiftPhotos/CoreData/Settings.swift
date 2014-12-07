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

    @NSManaged var imports: [Folder]
    @NSManaged var output: Folder

}
