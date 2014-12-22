//
//  BKTree.swift
//  SwiftPhotos
//
//  Created by Cameron Little on 12/20/14.
//  Copyright (c) 2014 Cameron Little. All rights reserved.
//
// http://blog.notdot.net/2007/4/Damn-Cool-Algorithms-Part-1-BK-Trees

import AppKit
import Foundation

//Assume for a moment we have two parameters, query, the string we are using in our search, and n the maximum distance a string can be from query and still be returned. Say we take an arbitary string, test and compare it to query. Call the resultant distance d. Because we know the triangle inequality holds, all our results must have at most distance d+n and at least distance d-n from test.
//
//From here, the construction of a BK-Tree is simple: Each node has a arbitrary number of children, and each edge has a number corresponding to a Levenshtein distance. All the subnodes on the edge numbered n have a Levenshtein distance of exactly n to the parent node. So, for example, if we have a tree with parent node "book" and two child nodes "rook" and "nooks", the edge from "book" to "rook" is numbered 1, and the edge from "book" to "nooks" is numbered 2.
//
//To build the tree from a dictionary, take an arbitrary word and make it the root of your tree. Whenever you want to insert a word, take the Levenshtein distance between your word and the root of the tree, and find the edge with number d(newword,root). Recurse, comparing your query with the child node on that edge, and so on, until there is no child node, at which point you create a new child node and store your new word there. For example, to insert "boon" into the example tree above, we would examine the root, find that d("book", "boon") = 1, and so examine the child on the edge numbered 1, which is the word "rook". We would then calculate the distance d("rook", "boon"), which is 2, and so insert the new word under "rook", with an edge numbered 2.
//
//To query the tree, take the Levenshtein distance from your term to the root, and recursively query every child node numbered between d-n and d+n (inclusive). If the node you are examining is within d of your search term, return it and continue your query.
//
//The tree is N-ary and irregular (but generally well-balanced). Tests show that searching with a distance of 1 queries no more than 5-8% of the tree, and searching with two errors queries no more than 17-25% of the tree - a substantial improvement over checking every node! Note that exact searching can also be performed fairly efficiently by simply setting n to 0.


class BKTree<T: Hashable> {
    private let compareFunc: (T, T) -> Int

    private var root: T?
    private var edges = [T:[(T, Int)]]()

    init(compare: (T, T) -> Int) {
        self.compareFunc = compare
    }

    func insert(node: T) {
        if root == nil {
            root = node
            return
        }
        _insert(node, root!)
    }

    private func _insert(node: T, _ root: T) {
        let d = compareFunc(node, root)
        if let children = edges[root] {
            for (child, d2) in children {
                if d2 == d {
                    _insert(node, child)
                    return
                }
            }
            // no child node width edge d, but child nodes exist
            edges[root]!.append((node, d))
        }
        // no child node
        edges[root] = [(node, d)]
    }

    func find(node: T, n: Int) -> [T] {
        var results = [T]()
        if let r = root {
            _find(node, root: r, n: n, results: &results)
        }
        return results
    }

    private func _find(node: T, root: T, n: Int, inout results: [T]) {
        let dist = compareFunc(node, root)
        if let children = edges[root] {
            for (child, d) in children {
                if abs(d - dist) <= n {
                    results.append(child)
                    _find(node, root: child, n: n, results: &results)
                }
            }
        }
    }
}

class PhotoBKTree {
    init() {
        return
    }

    private func compare(id1: NSManagedObjectID, id2: NSManagedObjectID, moc: NSManagedObjectContext) -> Int {
        if let p1 = moc.objectWithID(id1) as? Photo {
            if let p2 = moc.objectWithID(id2) as? Photo {
                if p1.ahash != nil && p2.ahash != nil {
                    return hammingDistance(p1.ahash!.unsignedLongLongValue, p2.ahash!.unsignedLongLongValue)
                }
            }
        }
        fatalError("Invalid photo inserted into bkTree.")
    }

    private var root: NSManagedObjectID?
    private var edges = [NSManagedObjectID:[(NSManagedObjectID, Int)]]()

    func insert(node: NSManagedObjectID, moc: NSManagedObjectContext) {
        if root == nil {
            root = node
            return
        }
        _insert(node, root!, moc: moc)
    }

    private func _insert(node: NSManagedObjectID, _ root: NSManagedObjectID, moc: NSManagedObjectContext) {
        let d = compare(node, id2: root, moc: moc)
        if let children = edges[root] {
            for (child, d2) in children {
                if d2 == d {
                    _insert(node, child, moc: moc)
                    return
                }
            }
            // no child node width edge d, but child nodes exist
            edges[root]!.append((node, d))
        }
        // no child node
        edges[root] = [(node, d)]
    }

    func find(node: NSManagedObjectID, n: Int, moc: NSManagedObjectContext) -> [NSManagedObjectID] {
        var results = [NSManagedObjectID]()
        if let r = root {
            _find(node, root: r, n: n, results: &results, moc: moc)
        }
        return results
    }

    private func _find(node: NSManagedObjectID, root: NSManagedObjectID, n: Int, inout results: [NSManagedObjectID], moc: NSManagedObjectContext) {
        let dist = compare(node, id2: root, moc: moc)
        if let children = edges[root] {
            for (child, d) in children {
                if abs(d - dist) <= n {
                    results.append(child)
                    _find(node, root: child, n: n, results: &results, moc: moc)
                }
            }
        }
    }

    func removeDuplicates(node: NSManagedObjectID, moc: NSManagedObjectContext) -> [NSManagedObjectID] {
        var results = [NSManagedObjectID]()
        if let r = root {
            _remove(node, root: r, results: &results, moc: moc)
        }
        return results
    }

    private func _remove(node: NSManagedObjectID, root: NSManagedObjectID, inout results: [NSManagedObjectID], moc: NSManagedObjectContext) {
        let dist = compare(node, id2: root, moc: moc)
        if let children = edges[root] {
            var toRemove = [Int]()
            for (i, (child, d)) in enumerate(children) {
                if abs(d - dist) <= 0 {
                    if node != child {
                        results.append(child)
                    }
                    _remove(node, root: child, results: &results, moc: moc)
                    if node != child {
                        toRemove.append(i)
                    }
                }
            }
            for i in toRemove.reverse() {
                edges[root]?.removeAtIndex(i)
            }
        }
    }
}