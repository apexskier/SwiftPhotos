//
//  BKTree.swift
//  SwiftPhotos
//
//  Created by Cameron Little on 12/20/14.
//  Copyright (c) 2014 Cameron Little. All rights reserved.
//
// http://blog.notdot.net/2007/4/Damn-Cool-Algorithms-Part-1-BK-Trees0
// http://nullwords.wordpress.com/2013/03/13/the-bk-tree-a-data-structure-for-spell-checking/

import AppKit
import Foundation

class PhotoBKTree {
    init() {
        return
    }

    private class PhotoBKTreeNode {
        let photoID: NSManagedObjectID
        var valid = true
        private var children = [Int: PhotoBKTreeNode]()

        init(photoID: NSManagedObjectID) {
            self.photoID = photoID
        }

        subscript(index: Int) -> PhotoBKTreeNode? {
            get {
                return children[index]?
            }
            set(id) {
                children[index] = id!
            }
        }

        var keys: LazyBidirectionalCollection<MapCollectionView<Dictionary<Int, PhotoBKTreeNode>, Int>> {
            get {
                return children.keys
            }
        }

        func containsKey(key: Int) -> Bool {
            return children[key] != nil
        }
    }

    private var _root: PhotoBKTreeNode?

    private func compare(id1: NSManagedObjectID, _ id2: NSManagedObjectID, moc: NSManagedObjectContext) -> Int {
        if id1 == id2 {
            return 0
        }
        if let p1 = moc.objectWithID(id1) as? Photo {
            if let p2 = moc.objectWithID(id2) as? Photo {
                if p1.ahash != nil && p2.ahash != nil {
                    return hammingDistance(p1.ahash!.unsignedLongLongValue, p2.ahash!.unsignedLongLongValue)
                }
            }
        }
        return Int.max
    }

    func insert(photoID id: NSManagedObjectID, managedObjectContext moc: NSManagedObjectContext) {
        if let root = _root {
            var curNode = root
            var d = compare(curNode.photoID, id, moc: moc)
            while (curNode.containsKey(d)) {
                if (d == 0) {
                    return
                }
                curNode = curNode[d]!
                d = compare(curNode.photoID, id, moc: moc)
            }
            curNode[d] = PhotoBKTreeNode(photoID: id)
        } else {
            _root = PhotoBKTreeNode(photoID: id)
        }
    }

    func remove(photoID id: NSManagedObjectID, managedObjectContext moc: NSManagedObjectContext) -> Bool {
        // TODO
        let similarNodes = nodeSearch(photoID: id, distance: 0, managedObjectContext: moc)
        for node in similarNodes {
            if node.photoID == id {
                node.valid = false
            }
        }
        if let root = _root {
            var orphaned = [PhotoBKTreeNode]()
            if root.photoID == id {
                return false
            }
        }
        return false
    }

    func search(photoID id: NSManagedObjectID, distance d: Int, managedObjectContext moc: NSManagedObjectContext) -> [NSManagedObjectID] {
        let similarNodes = nodeSearch(photoID: id, distance: d, managedObjectContext: moc)
        var ret = [NSManagedObjectID]()
        return similarNodes.filter({ (node: PhotoBKTreeNode) -> Bool in
            return node.valid
        }).map({ (node: PhotoBKTreeNode) -> NSManagedObjectID in
            return node.photoID
        })
    }

    private func nodeSearch(photoID id: NSManagedObjectID, distance d: Int, managedObjectContext moc: NSManagedObjectContext) -> [PhotoBKTreeNode] {
        var ret = [PhotoBKTreeNode]()
        _search(_root, ret: &ret, photoID: id, distance: d, managedObjectContext: moc)
        return ret
    }

    private func _search(_node: PhotoBKTreeNode?, inout ret: [PhotoBKTreeNode], photoID id: NSManagedObjectID, distance d: Int, managedObjectContext moc: NSManagedObjectContext) {
        if let node = _node {
            let curDist = compare(node.photoID, id, moc: moc)
            let minDist = curDist - d
            let maxDist = curDist + d

            if curDist <= d {
                ret.append(node)
            }

            for key in node.keys.filter({ (key: Int) -> Bool in
                return (minDist <= key) && (key <= maxDist)
            }) {
                _search(node[key], ret: &ret, photoID: id, distance: d, managedObjectContext: moc)
            }
        }
    }
}
