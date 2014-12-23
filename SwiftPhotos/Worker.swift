//
//  Worker.swift
//  SwiftPhotos
//
//  Created by Cameron Little on 12/22/14.
//  Copyright (c) 2014 Cameron Little. All rights reserved.
//

import AppKit
import Foundation
import Dispatch

class Worker {
    var name: String

    private lazy var managedObjectContext: NSManagedObjectContext = {
        let moc = NSManagedObjectContext(concurrencyType: .MainQueueConcurrencyType)
        moc.persistentStoreCoordinator = CoreDataStackManager.sharedManager.persistentStoreCoordinator
        return moc
    }()

    let queue: dispatch_queue_t

    private var observers: [AnyObject] = []

    private var running = true

    private var predicate = NSPredicate()

    func start() {
        for observer in observers {
            NSNotificationCenter.defaultCenter().removeObserver(observer)
        }
        dispatch_async(queue, {
            while self.running {
                // do work
                self.work(&self.running)
            }
            dispatch_async(dispatch_get_main_queue(), {
                self.observers.append(NSNotificationCenter.defaultCenter().addObserverForName("alert\(self.name)", object: nil, queue: nil, usingBlock: { (notification: NSNotification!) in
                    self.start()
                }))
            });
        });
    }

    private func work(inout cont: Bool) {
        var error: NSError?

        let request = NSFetchRequest(entityName: "Photo")
        request.predicate = predicate
        request.fetchLimit = 1

        if let results = managedObjectContext.executeFetchRequest(request, error: &error) {
            if results.count > 0 {
                let photo = results[0] as Photo
                println("\(self.name) working on \(photo.filepath)")
                task(photo)

                if !managedObjectContext.save(&error) {
                    println("Coudn't save moc: \(error)")
                }
            } else {
                cont = false
            }
        } else {
            fatalError("Failed to execute fetch request: \(error)")
        }
    }

    private func task(photo: Photo) {
        fatalError("Superclass worker run")
    }
    init (name: String) {
        self.name = name
        queue = dispatch_queue_create("com.camlittle.SwiftPhotos.\(name)", nil)
    }

    deinit {
        for observer in observers {
            NSNotificationCenter.defaultCenter().removeObserver(observer)
        }

        var error: NSError?
        if !self.managedObjectContext.save(&error) {
            fatalError("Error saving: \(error)")
        }
    }
}

class DiscoveryWorker: Worker {
    init() {
        super.init(name: "DiscoveryWorker")

        self.predicate = NSPredicate(format: "state == 0",
            argumentArray: [])
    }

    override func task(photo: Photo) {
        photo.readData()
        photo.stateEnum = .Known
    }
}

class HashWorker: Worker {
    var appDelegate: AppDelegate
    init(delegate: AppDelegate) {
        self.appDelegate = delegate

        super.init(name: "HashWorker")
        
        self.predicate = NSPredicate(format: "ahash = nil OR fhash = nil",
            argumentArray: [])
    }

    override func task(photo: Photo) {
        photo.genFhash()
        // photo.genPhash()
        photo.genAhash()

        let dups = appDelegate.bkTree.find(photo.objectID, n: 0, moc: managedObjectContext)
        if dups.count > 0 {
            for p in dups {
                let ph = managedObjectContext.objectWithID(p) as Photo
                let duplicates = photo.mutableSetValueForKey("duplicates")
                if !duplicates.containsObject(ph) {
                    duplicates.addObject(ph)
                }
            }
        }
        appDelegate.bkTree.insert(photo.objectID, moc: managedObjectContext)
    }
}

class QualityWorker: Worker {
    init() {
        super.init(name: "QualityWorker")

        self.predicate = NSPredicate(format: "exposure = nil",
            argumentArray: [])
    }

    override func task(photo: Photo) {
        photo.genQualityMeasures()
    }
}