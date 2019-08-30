import CoreLocation

open class Annotation: NSObject {
    
    public weak var location: CLLocation?
    public weak var calloutImage: UIImage?
    public weak var anchor: MBARAnchor?
    
    public init(location: CLLocation, calloutImage: UIImage?) {
        self.location = location
        self.calloutImage = calloutImage
    }
    
}
