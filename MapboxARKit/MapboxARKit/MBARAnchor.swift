import ARKit
import CoreLocation

public class MBARAnchor: ARAnchor {
    
    public var calloutString: String?
    
    public convenience init(originLocation: CLLocation, location: CLLocation) {        
        let transform = matrix_identity_float4x4.transformMatrix(originLocation: originLocation, location: location)
        self.init(transform: transform)
    }
    
}

internal extension simd_float4x4 {
    
    // Effectively copy the position of the start location, rotate it about
    // the bearing of the end location and "push" it out the required distance
    func transformMatrix(originLocation: CLLocation, location: CLLocation) -> simd_float4x4 {
        // Determine the distance and bearing between the start and end locations
        let distance = Float(location.distance(from: originLocation))
        let bearingDegrees = originLocation.bearingTo(endLocation: location)
        let bearing = GLKMathDegreesToRadians(bearingDegrees)
        
        // Effectively copy the position of the start location, rotate it about
        // the bearing of the end location and "push" it out the required distance
        let position = vector_float4(0.0, 0.0, -distance, 0.0)
        let translationMatrix = matrix_identity_float4x4.translationMatrix(position)
        let rotationMatrix = matrix_identity_float4x4.rotationAroundY(radians: bearing)
        let transformMatrix = simd_mul(rotationMatrix, translationMatrix)
        return simd_mul(self, transformMatrix)
    }
    
}

internal extension matrix_float4x4 {
    
    func rotationAroundY(radians: Float) -> matrix_float4x4 {
        var m : matrix_float4x4 = self;
        
        m.columns.0.x = cos(radians);
        m.columns.0.z = -sin(radians);
        
        m.columns.2.x = sin(radians);
        m.columns.2.z = cos(radians);
        
        return m.inverse;
    }
    
    func translationMatrix(_ translation : vector_float4) -> matrix_float4x4 {
        var m : matrix_float4x4 = self
        m.columns.3 = translation
        return m
    }
    
}

internal extension CLLocation {
    
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
