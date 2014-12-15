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
            for event in events {
                let path = NSString(string: "file://\(event.path)").stringByAddingPercentEscapesUsingEncoding(NSUTF8StringEncoding)!
                let pathURL = NSURL(string: path)!
                let filename = pathURL.lastPathComponent!
                
                if filename[filename.startIndex] != "." {
                    let	flagsRaw = event.flag.rawValue
                    var action = false
                    for i:UInt32 in 0..<16 {
                        let	flag = 0b01 << i
                        let	ok = (flag & flagsRaw) > 0
                        if ok {
                            // this flag was found
                            let	s = "\(StringFromEventFlag(flag)) \(path)"
                            switch Int(flag) {
                            case kFSEventStreamEventFlagUnmount:
                                println(s)
                            case kFSEventStreamEventFlagItemCreated:
                                self.appDelegate.changeFound(pathURL, change: .Added)
                                action = true
                            case kFSEventStreamEventFlagItemRemoved:
                                self.appDelegate.changeFound(pathURL, change: .Removed)
                                action = true
                            case kFSEventStreamEventFlagItemInodeMetaMod:
                                break
                            case kFSEventStreamEventFlagItemRenamed:
                                // Moved, moved to trash, restored from trash
                                let fm = NSFileManager.defaultManager()
                                if fm.fileExistsAtPath(event.path) {
                                    // file is there
                                    var info: NSURLRelationship = NSURLRelationship.Other
                                    var error: NSError?
                                    for folderPath in self.paths {
                                        let folderPathEncoded = NSString(string: "file://\(folderPath)").stringByAddingPercentEscapesUsingEncoding(NSUTF8StringEncoding)!
                                        if fm.getRelationship(&info, ofDirectoryAtURL: NSURL(string: folderPathEncoded)!, toItemAtURL: pathURL, error: &error) {
                                            if info == NSURLRelationship.Contains {
                                                self.appDelegate.changeFound(pathURL, change: .Added)
                                                break
                                            } else if info == NSURLRelationship.Same {
                                                fatalError("A core folder was changed: \(path)")
                                                break
                                            }
                                        }
                                    }
                                } else {
                                    // file missing
                                    self.appDelegate.changeFound(pathURL, change: .Removed)
                                }
                                action = true
                            case kFSEventStreamEventFlagItemModified:
                                // Moved, moved to trash, restored from trash
                                let fm = NSFileManager.defaultManager()
                                if fm.fileExistsAtPath(path) {
                                    // file is there
                                    self.appDelegate.changeFound(pathURL, change: .Changed)
                                } else {
                                    // file missing
                                    self.appDelegate.changeFound(pathURL, change: .Removed)
                                }
                                action = true
                            case kFSEventStreamEventFlagItemFinderInfoMod:
                                println(s)
                            case kFSEventStreamEventFlagItemChangeOwner:
                                println(s)
                            case kFSEventStreamEventFlagItemXattrMod:
                                println(s)
                            case kFSEventStreamEventFlagItemIsFile:
                                println(s)
                            case kFSEventStreamEventFlagItemIsDir:
                                println(s)
                            case kFSEventStreamEventFlagItemIsSymlink:
                                println(s)
                            default:
                                println(s)
                            }

                        }
                    }
                }
            }
        })
    }
    
    var paths: [String] = []
        
    func loadPaths() {
        let appDelegate = NSApplication.sharedApplication().delegate as AppDelegate
        let settings = appDelegate.settings
        
        paths = []
        if settings.imports.count > 0 {
            for i in 0...(settings.imports.count - 1) {
                let path: String = settings.imports[i].path!!
                paths.append(NSURL(string: path)!.relativePath!)
            }
        }
        if let output = settings.output {
            if let url = NSURL(string: output.path) {
                if let urlpath = url.relativePath {
                    paths.append(urlpath)
                }
            }
        }
    }
    
    func start() {
        loadPaths()
        if paths.count > 0 {
            monitor = EonilFileSystemEventStream(
                callback: callback,
                pathsToWatch: paths,
                latency: latency,
                watchRoot: false,
                queue: queue)
        }
    }
    
}