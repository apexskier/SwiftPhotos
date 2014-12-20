//
//  FileSystemEvents.swift
//  SwiftPhotos
//
//  Created by Cameron Little on 12/14/14.
//  Copyright (c) 2014 Cameron Little. All rights reserved.
//

import Foundation

func StringFromEventFlag(flag: FSEventStreamEventFlags) -> String {
    switch Int(flag) {
    case kFSEventStreamEventFlagNone:
        return "None"
    case kFSEventStreamEventFlagMustScanSubDirs:
        return "MustScanSubDirs"
    case kFSEventStreamEventFlagUserDropped:
        return "UserDropped"
    case kFSEventStreamEventFlagKernelDropped:
        return "KernelDropped"
    case kFSEventStreamEventFlagEventIdsWrapped:
        return "EventIdsWrapped"
    case kFSEventStreamEventFlagHistoryDone:
        return "HistoryDone"
    case kFSEventStreamEventFlagRootChanged:
        return "RootChanged"
    case kFSEventStreamEventFlagMount:
        return "Mount"
        
    case kFSEventStreamEventFlagUnmount:
        return "Unmount"
    case kFSEventStreamEventFlagItemCreated:
        return "ItemCreated"
    case kFSEventStreamEventFlagItemRemoved:
        return "ItemRemoved"
    case kFSEventStreamEventFlagItemInodeMetaMod:
        return "ItemInodeMetaMod"
    case kFSEventStreamEventFlagItemRenamed:
        return "ItemRenamed"
    case kFSEventStreamEventFlagItemModified:
        return "ItemModified"
    case kFSEventStreamEventFlagItemFinderInfoMod:
        return "ItemFinderInfoMod"
    case kFSEventStreamEventFlagItemChangeOwner:
        return "ItemChangeOwner"
    case kFSEventStreamEventFlagItemXattrMod:
        return "ItemXattrMod"
    case kFSEventStreamEventFlagItemIsFile:
        return "ItemIsFile"
    case kFSEventStreamEventFlagItemIsDir:
        return "ItemIsDir"
    case kFSEventStreamEventFlagItemIsSymlink:
        return "ItemIsSymlink"
    case kFSEventStreamEventFlagOwnEvent:
        return "OwnEvent"
        
    default:
        return "????"
    }
}