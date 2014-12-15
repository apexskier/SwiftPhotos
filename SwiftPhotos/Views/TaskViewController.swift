//
//  TaskViewController.swift
//  SwiftPhotos
//
//  Created by Cameron Little on 12/13/14.
//  Copyright (c) 2014 Cameron Little. All rights reserved.
//

import Cocoa
import Foundation

class TaskViewController: NSViewController {
    
    private var appDelegate = NSApplication.sharedApplication().delegate as AppDelegate
    @IBOutlet weak var discoveryProgress: NSProgressIndicator!
    @IBOutlet weak var discoveryText: NSTextField!
    @IBOutlet weak var hashProgress: NSProgressIndicator!
    @IBOutlet weak var hashText: NSTextField!
    @IBOutlet weak var qualityProgress: NSProgressIndicator!
    @IBOutlet weak var qualityText: NSTextField!
    
    var observers: [AnyObject] = []
    
    // MARK: View Life Cycle
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    override func viewDidDisappear() {
        for observer in observers {
            NSNotificationCenter.defaultCenter().removeObserver(observer)
        }
    }
    
    override func viewWillAppear() {
        observers.append(NSNotificationCenter.defaultCenter().addObserverForName("completedTask", object: nil, queue: nil, usingBlock: { (notification: NSNotification!) in
            var d = Double(TaskManager.sharedManager.pendingDiscoveries.queue.operationCount)
            var h = Double(TaskManager.sharedManager.pendingHashes.queue.operationCount)
            var q = Double(TaskManager.sharedManager.pendingQuality.queue.operationCount)
            
            if d > self.discoveryProgress.maxValue {
                self.discoveryProgress.maxValue = d
            }
            if h > self.hashProgress.maxValue {
                self.hashProgress.maxValue = h
            }
            if q > self.qualityProgress.maxValue {
                self.qualityProgress.maxValue = q
            }
            self.reloadView()
        }))
        
        var d = TaskManager.sharedManager.pendingDiscoveries.queue.operationCount
        var h = TaskManager.sharedManager.pendingHashes.queue.operationCount
        var q = TaskManager.sharedManager.pendingQuality.queue.operationCount
        
        if d > 0 {
            discoveryProgress.maxValue = Double(d)
        }
        if h > 0 {
            hashProgress.maxValue = Double(h)
        }
        if q > 0 {
            qualityProgress.maxValue = Double(q)
        }
        
        reloadView()
        super.viewWillAppear()
    }
    
    func reloadView() {
        var d = TaskManager.sharedManager.pendingDiscoveries.queue.operationCount
        var h = TaskManager.sharedManager.pendingHashes.queue.operationCount
        var q = TaskManager.sharedManager.pendingQuality.queue.operationCount
            
        discoveryText.stringValue = "Discoveries: \(d)"
        hashText.stringValue = "Hashes: \(h)"
        qualityText.stringValue = "Quality Generations: \(q)"
        
        discoveryProgress.doubleValue = Double(d)
        hashProgress.doubleValue = Double(h)
        qualityProgress.doubleValue = Double(q)
    }

}