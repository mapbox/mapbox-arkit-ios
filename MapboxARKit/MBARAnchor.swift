import ARKit
import CoreLocation
import Turf

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
        var distance = Float(location.distance(from: originLocation))
        
        // Workaround to set the minum size of the node. Enforce the distance if distance is over than 200m
        if distance > 200 {
           distance = 200
        }
        
        if distance < 50 {
            distance = 50
        }
        
        let bearing = GLKMathDegreesToRadians(Float(originLocation.coordinate.direction(to: location.coordinate)))
        
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
