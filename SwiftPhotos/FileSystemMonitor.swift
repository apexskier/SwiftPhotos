//
//  FileSystemMonitor.swift
//  SwiftPhotos
//
//  Created by Cameron Little on 12/14/14.
//  Copyright (c) 2014 Cameron Little. All rights reserved.
//

import Foundation
import AppKit

enum FileChange {
    case Changed
    case Removed
    case Added
}

class FileSystemMonitor {
    class var sharedManager: FileSystemMonitor {
        struct Singleton {
            static let manager = FileSystemMonitor()
        }

        return Singleton.manager
    }

    private var latency: NSTimeInterval = 0

    private var appDelegate = NSApplication.sharedApplication().delegate as AppDelegate
    private var settings: Settings {
        get {
            return appDelegate.settings
        }
    }

    private var queue = dispatch_get_global_queue(QOS_CLASS_BACKGROUND, 0)

    var monitor: EonilFileSystemEventStream?

    func callback(events: [AnyObject]!) {
        let	events = events! as [EonilFileSystemEvent]
        dispatch_async(dispatch_get_main_queue(), { () -> Void in
            let fm = NSFileManager.defaultManager()
            for event in events {
                let path = NSString(string: "file://\(event.path)").stringByAddingPercentEscapesUsingEncoding(NSUTF8StringEncoding)!
                let pathURL = NSURL(string: path)!
                let filename = pathURL.lastPathComponent!

                var info: NSURLRelationship = NSURLRelationship.Other
                var error: NSError?
                for folderPath in self.paths {
                    if fm.getRelationship(&info, ofDirectoryAtURL: folderPath, toItemAtURL: pathURL, error: &error) {
                        if info == NSURLRelationship.Same {
                            fatalError("A core folder was changed: \(path)")
                        }
                    }
                }

                // assume file is in the folders I'm concerned with
                if filename[filename.startIndex] != "." {
                    let	flagsRaw = event.flag.rawValue
                    eventsLoop: for i:UInt32 in 0..<16 {
                        let	flag = 0b01 << i
                        let	ok = (flag & flagsRaw) > 0
                        if ok {
                            // this flag was found
                            let	s = "\(StringFromEventFlag(flag)) \(path)"
                            println(s)
                            switch Int(flag) {
                            case kFSEventStreamEventFlagUnmount:
                                break
                            case kFSEventStreamEventFlagItemCreated:
                                // NOTE: This appears to always be followed by a Modified event
                                self.appDelegate.changeFound(pathURL)
                                break eventsLoop
                            case kFSEventStreamEventFlagItemRemoved:
                                self.appDelegate.changeFound(pathURL)
                                break eventsLoop
                            case kFSEventStreamEventFlagItemInodeMetaMod:
                                break
                            case kFSEventStreamEventFlagItemRenamed:
                                // Moved, moved to trash, restored from trash
                                self.appDelegate.changeFound(pathURL)
                                break eventsLoop
                            case kFSEventStreamEventFlagItemModified:
                                // Moved, moved to trash, restored from trash
                                self.appDelegate.changeFound(pathURL)
                                break eventsLoop
                            case kFSEventStreamEventFlagItemFinderInfoMod:
                                break
                            case kFSEventStreamEventFlagItemChangeOwner:
                                break
                            case kFSEventStreamEventFlagItemXattrMod:
                                break
                            case kFSEventStreamEventFlagItemIsFile:
                                break
                            case kFSEventStreamEventFlagItemIsDir:
                                break
                            case kFSEventStreamEventFlagItemIsSymlink:
                                break
                            default:
                                break
                            }
                        }
                    }
                }
            }
        })
    }

    var paths = [NSURL]()
    var outputPath: NSURL?

    func loadPaths() {
        let appDelegate = NSApplication.sharedApplication().delegate as AppDelegate
        let settings = appDelegate.settings

        paths = []
        if settings.inputs.count > 0 {
            for i in 0...(settings.inputs.count - 1) {
                let path: String = settings.inputs[i].path!!
                paths.append(NSURL(string: path)!)
            }
        }

        if let output = settings.output {
            if let url = NSURL(string: output.path) {
                outputPath = url
            }
        }
    }

    func start() {
        loadPaths()
        var newPaths = paths // should copy
        if let p = outputPath {
            if p.relativePath != nil && p.relativePath! != "" {
                newPaths.append(p)
            }
        }
        if newPaths.count > 0 {
            monitor = EonilFileSystemEventStream(
                callback: callback,
                pathsToWatch: newPaths.map({ (url: NSURL) in
                    return url.relativePath!
                }),
                latency: latency,
                watchRoot: false,
                queue: queue)
        }
    }
}
