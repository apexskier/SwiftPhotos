//
//  PathArray.swift
//  SwiftPhotos
//
//  Created by Cameron Little on 8/12/14.
//  Copyright (c) 2014 Cameron Little. All rights reserved.
//

import Foundation
import CoreData
import AppKit

class PathArrayTable: NSObject, NSTableViewDataSource, NSTableViewDelegate {
    var paths: [String] = []
    
    func numberOfRowsInTableView(aTableView: NSTableView!) -> Int {
        return self.paths.count
    }
    
    func tableView(tableView: NSTableView!, objectValueForTableColumn tableColumn: NSTableColumn!, row: Int) -> AnyObject! {
        return self.paths[row] as NSString;
    }
    
    func getDataArray() -> NSArray {
        println(paths);
        var array: [String] = []
        for item in paths {
            //array.append(item.relativePath!)
        }
        return array as NSArray;
    }
    
    func append(item: NSURL) {
        let str = item.absoluteString!
        /*let ctx = self.managedObjectContext!
        let entity =  NSEntityDescription.entityForName("Path", inManagedObjectContext: ctx)
        let path = NSManagedObject(entity: entity!, insertIntoManagedObjectContext: ctx)
        
        path.setValue(str, forKey: "path")
        
        var error: NSError?
        if !ctx.save(&error) {
            println("Could not save \(error), \(error?.userInfo)")
        }
        
        var rel = valueForKeyPath("paths") as NSMutableSet
        rel.addObject(entity!)// += [item.absoluteURL]*/
        //setValue(paths, "paths")
        //self.items.append(item)
    }
    
    func removeAt(index: Int) {
        self.paths.removeAtIndex(index)
    }
    
}