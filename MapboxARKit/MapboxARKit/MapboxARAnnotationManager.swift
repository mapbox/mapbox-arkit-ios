import ARKit
import SpriteKit
import CoreLocation
import GLKit

// A preview of an API for abstracting the notion of annotations and GeoJSON for use in AR

public class MapboxARAnnotationManager {
    
    private(set) var anchors = [ARAnchor]()
    private var session: ARSession
    
    public init(session: ARSession) {
        self.session = session
    }
    
    public func addARAnnotation(startLocation: CLLocation, endLocation: CLLocation, calloutString: String?) {
        let origin = matrix_identity_float4x4
        
        // Determine the distance and bearing between the start and end locations
        let distance = Float(endLocation.distance(from: startLocation))
        let bearingDegrees = startLocation.bearingTo(endLocation: endLocation)
        let bearing = GLKMathDegreesToRadians(bearingDegrees)
        
        // Effectively copy the position of the start location, rotate it about
        // the bearing of the end location and "push" it out the required distance
        let position = vector_float4(0.0, 0.0, -distance, 0.0)
        let translationMatrix = getTranslationMatrix(position)
        let rotationMatrix = getRotationAroundY(bearing)
        let transformMatrix = simd_mul(rotationMatrix, translationMatrix)
        let transform = simd_mul(origin, transformMatrix)
        
        // Create a Mapbox AR anchor anchor at the transformed position
        let anchor = MapboxARAnchor(transform: transform)
        
        // Set the callout string (if any) on the anchor
        anchor.calloutString = calloutString
        
        // Add the anchor to the session
        session.add(anchor: anchor)
        anchors.append(anchor)
    }
    
    public func removeAllARAnchors() {
        for anchor in anchors {
            session.remove(anchor: anchor)
        }
        anchors.removeAll()
    }
    
}

// Matrix utilities from https://developer.apple.com/library/content/samplecode/AdoptingMetalII/Listings/ObjectsExample_Utils_swift.html
extension MapboxARAnnotationManager {
    
    private func getRotationAroundY(_ radians : Float) -> matrix_float4x4 {
        var m : matrix_float4x4 = matrix_identity_float4x4;
        
        m.columns.0.x = cos(radians);
        m.columns.0.z = -sin(radians);
        
        m.columns.2.x = sin(radians);
        m.columns.2.z = cos(radians);
        
        return m.inverse;
    }
    
    private func getTranslationMatrix(_ translation : vector_float4) -> matrix_float4x4 {
        var m : matrix_float4x4 = matrix_identity_float4x4
        m.columns.3 = translation
        return m
    }
    
}

private extension CLLocation {
    
    // https://stackoverflow.com/questions/26998029/calculating-bearing-between-two-cllocation-points-in-swift
    func bearingTo(endLocation: CLLocation) -> Float {
        
        var bearing: Float = 0.0
        
        let latitudeStart = GLKMathDegreesToRadians(Float(coordinate.latitude))
        let longitudeStart = GLKMathDegreesToRadians(Float(coordinate.longitude))
        let latitudeEnd = GLKMathDegreesToRadians(Float(endLocation.coordinate.latitude))
        let longitudeEnd = GLKMathDegreesToRadians(Float(endLocation.coordinate.longitude))
        let longitudinalDistance = longitudeEnd - longitudeStart
        let y = sin(longitudinalDistance) * cos(latitudeEnd)
        let x = cos(latitudeStart) * sin(latitudeEnd) - sin(latitudeStart) * cos(latitudeEnd) * cos(longitudinalDistance)
        let radiansBearing = atan2(y, x)
        
        bearing = GLKMathRadiansToDegrees(radiansBearing)
        
        return bearing
    }
    
}
