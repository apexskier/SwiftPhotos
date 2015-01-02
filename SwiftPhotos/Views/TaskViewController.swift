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
            var d = Double(TaskManager.sharedManager.queue.operationCount)
            
            if d > self.discoveryProgress.maxValue {
                self.discoveryProgress.maxValue = d
            }
            self.reloadView()
        }))
        
        var d = TaskManager.sharedManager.queue.operationCount
        
        if d > 0 {
            discoveryProgress.maxValue = Double(d)
        }
        
        reloadView()
        super.viewWillAppear()
    }
    
    func reloadView() {
        var d = TaskManager.sharedManager.queue.operationCount
        discoveryText.stringValue = "Tasks: \(d)"
        discoveryProgress.doubleValue = Double(d)
    }
}