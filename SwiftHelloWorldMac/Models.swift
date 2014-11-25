//
//  Model.swift
//  SwiftHelloWorldMac
//
//  Created by Cameron Little on 11/23/14.
//  Copyright (c) 2014 Cameron Little. All rights reserved.
//

import CoreData
import Foundation

class Path: NSManagedObject {
    @NSManaged var path: String
}