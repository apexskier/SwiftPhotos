//
//  DelaunyTriangulation.swift
//  SwiftPhotos
//
//  Created by Cameron Little on 1/10/15.
//  Copyright (c) 2015 Cameron Little. All rights reserved.
//

import Foundation

extension Array {
    mutating func remove<U: Equatable>(object: U) {
        var index: Int?
        for (idx, objectToCompare) in enumerate(self) {
            if let to = objectToCompare as? U {
                if object == to {
                    index = idx
                }
            }
        }
        
        if (index != nil) {
            self.removeAtIndex(index!)
        }
    }
    
    mutating func remove<U: Equatable>(objects: [U]) {
        for object in objects {
            remove(object)
        }
    }
}

struct Point {
    var x: Float
    var y: Float
}
extension Point: Equatable {}
func == (a: Point, b: Point) -> Bool {
    return a.x == b.x && a.y == b.y
}
func - (a: Point, b: Point) -> Point {
    return Point(x: a.x - b.x, y: a.y - b.y)
}

struct Edge {
    var pointA: Point
    var pointB: Point
    var length: Float {
        get {
            let asq = pow(pointB.x - pointA.x, 2)
            let bsq = pow(pointB.y - pointB.y, 2)
            return abs(pow(asq + bsq, 0.5))
        }
    }
}
extension Edge: Equatable {}
// No direction is implied.
func == (a: Edge, b: Edge) -> Bool {
    return (a.pointA == b.pointA && a.pointB == b.pointB) ||
        (a.pointA == b.pointB && a.pointB == b.pointA)
}

class Triangle {
    var vertexA: Point
    var vertexB: Point
    var vertexC: Point
    
    var edgeA: Edge {
        get {
            return Edge(pointA: vertexA, pointB: vertexB)
        }
    }
    var edgeB: Edge {
        get {
            return Edge(pointA: vertexB, pointB: vertexC)
        }
    }
    var edgeC: Edge {
        get {
            return Edge(pointA: vertexC, pointB: vertexA)
        }
    }
    
    var circumcenter: Point {
        get {
            let A = Point(x: 0, y: 0)
            let B = vertexB - vertexA
            let C = vertexC - vertexA
            let d = 2 * (B.x*C.y - B.y*C.x)
            
            let bcomp = pow(B.x, 2) + pow(B.y, 2)
            let ccomp = pow(C.x, 2) + pow(C.y, 2)
            let x = (C.y*bcomp - B.y*ccomp) / d
            let y = (B.x*ccomp - C.x*bcomp) / d
            
            return Point(x: x, y: y)
        }
    }
    
    var circumdiameter: Float {
        get {
            let a = edgeA.length
            let b = edgeB.length
            let c = edgeC.length
            let s = (a + b + c) / 2
            
            let top = 2 * a * b * c
            let comb: Float = { () -> Float in
                let one = (a+b+c)
                let two = (-a+b+c)
                let three = (a-b+c)
                let four = (a+b-c)
                return one * two * three * four
            }()
            let bottom = pow(comb, 0.5)
            
            return top / bottom
        }
    }
    
    init(vertexA: Point, vertexB: Point, vertexC: Point) {
        self.vertexA = vertexA
        self.vertexB = vertexB
        self.vertexC = vertexC
    }
    
    init(edgeA: Edge, edgeB: Edge) {
        vertexA = edgeA.pointA
        vertexB = edgeA.pointB
        if edgeB.pointA == vertexA {
            vertexC = edgeB.pointB
        } else {
            vertexC = edgeB.pointA
        }
    }
    
    init(edge: Edge, point: Point) {
        vertexA = point
        vertexB = edge.pointA
        vertexC = edge.pointB
    }
    
    func circumcircleContains(point: Point) -> Bool {
        return Edge(pointA: point, pointB: circumcenter).length < circumdiameter
    }
    
    var edges: [Edge] {
        return [Edge(pointA: vertexA, pointB: vertexB),
                Edge(pointA: vertexB, pointB: vertexC),
                Edge(pointA: vertexC, pointB: vertexA)]
    }
    
    var vertices: [Point] {
        return [vertexA, vertexB, vertexC]
    }
    
    func containsEdge(edge: Edge) -> Bool {
        for ownEdge in edges {
            if ownEdge == edge {
                return true
            }
        }
        return false
    }
    
    func sharesEdge(triangle: Triangle) -> Bool {
        for edge in edges {
            if triangle.containsEdge(edge) {
                return true
            }
        }
        return false
    }
    
    func containsVertex(point: Point) -> Bool {
        return (point == vertexA) || (point == vertexB) || (point == vertexC)
    }
    
    func sharesVertex(triangle: Triangle) -> Bool {
        for vertex in vertices {
            if triangle.containsVertex(vertex) {
                return true
            }
        }
        return false
    }
}
extension Triangle: Equatable {}
// No direction is implied.
func == (a: Triangle, b: Triangle) -> Bool {
    for edge in a.edges {
        if b.containsEdge(edge) {
            return true
        }
    }
    return false
}

private func SuperTriangle(points: [Point]) -> Triangle {
    // TODO
    return Triangle(vertexA: Point(x: 0, y: 0), vertexB: Point(x: 0, y: 1), vertexC: Point(x: 1, y: 0))
}

private func BowyerWatson(points: [Point]) -> [Triangle] {
    // pointList is a set of coordinates defining the points to be triangulated
    var triangulation: [Triangle] = []
    let superTriangle = SuperTriangle(points)
    // must be large enough to completely contain all the points in pointList
    triangulation.append(superTriangle)
    // add all the points one at a time to the triangulation
    for point in points {
        // first find all the triangles that are no longer valid due to the insertion
        var badTriangles: [Triangle] = []
        for triangle in triangulation {
            if triangle.circumcircleContains(point) {
                badTriangles.append(triangle)
            }
        }
        var polygon: [Edge] = []
        for triangle in badTriangles {
            for edge in triangle.edges {
                // edge isn't shared by any other triangle in badTriangles
                if !{ () -> Bool in
                    for tri in badTriangles {
                        if tri == triangle {
                            continue
                        }
                        if tri.containsEdge(edge) {
                            return true
                        }
                    }
                    return false
                }() {
                    polygon.remove(edge)
                    polygon.append(edge)
                }
            }
        }
        triangulation.remove(badTriangles)
        for edge in polygon {
            triangulation.append(Triangle(edge: edge, point: point))
        }
    }
    for triangle in triangulation {
        if triangle.sharesVertex(superTriangle) {
            triangulation.remove(triangle)
        }
    }
    return triangulation
}

class DelaunyTriangulation {
    private var points: [Point] = []
    private var triangles: [Triangle]
    init(points: [Point]) {
        self.points = points
        self.triangles = BowyerWatson(points)
    }
}