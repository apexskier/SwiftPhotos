//
//  PathArray.swift
//  SwiftHelloWorldMac
//
//  Created by Cameron Little on 8/12/14.
//  Copyright (c) 2014 Daniel Bergquist. All rights reserved.
//

import Foundation
import AppKit

class pathArray: NSObject, NSTableViewDataSource, NSTableViewDelegate {
    var items: [NSURL] = []
    
    func numberOfRowsInTableView(aTableView: NSTableView!) -> Int {
        return self.items.count
    }
    
    func tableView(tableView: NSTableView!, objectValueForTableColumn tableColumn: NSTableColumn!, row: Int) -> AnyObject! {
        return self.items[row].description as NSString;
    }
    
    func getDataArray() -> NSArray {
        println(items);
        var array: [String] = []
        for item in items {
            array.append(item.relativePath)
        }
        return array as NSArray;
    }
    
    convenience override init() {
        self.init(array: [])
    }
    init(array: [NSURL]) {
        super.init()
        self.items = array
    }
    
    func append(item: NSURL) {
        self.items.append(item)
    }
    
    func removeAt(index: Int) {
        self.items.removeAtIndex(index)
    }
}