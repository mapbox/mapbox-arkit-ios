# MapboxARKit 

Utilities for combining Mapbox maps and location services with ARKit in your applications.

_**Warning:** The MapboxARKit API is **experimental** and will change. It is published to be able to get feedback from the community. Please use with caution and open issues for any problems you see or missing features that should be added._

### Usage

_Coming soon!_

### Installation

**Requirements:**
* Xcode 9 Beta 5 or higher
* An iDevice with an A9 (or greater) processor running iOS 11 Beta 5 or higher
* [Carthage](https://github.com/Carthage/Carthage) )for development and running the sample app)
* [CocoaPods](http://guides.cocoapods.org/using/getting-started.html#installation) (for installing the library in your own app)

#### Adding MapboxARKit to your iOS app

Although there has not yet been a beta release of this library yet, you can still experiment with it in your application by using CocoaPods to install it. Edit your Podfile to include:

TODO!
```
# pod 'MapboxARKit', :git => 'git@github.com:mapbox/mapbox-arkit-ios.git'
```

NOTE: There is currently an issue with the Xcode beta and GPU frame capture: https://stackoverflow.com/questions/45368426/mapbox-crashes-when-used-with-scenekit. You can fix that by following these instructions: https://stackoverflow.com/questions/31264537/adding-google-maps-as-subview-crashes-ios-app-with-exc-bad/31445847#31445847 -- If you see this error in your project, edit your scheme and change "GPU Frame Capture" from "Automatically Enabled" or "OpenGL ES" to either "Metal" or "Disabled"

#### Running the sample project

* Run `scripts/setup.sh`. This script will check that you have Carthage installed and, if so, install the development dependencies
* Open `MapboxARKit.xcodeproj` in Xcode 9
* Select the `MapboxARKitDemoApp` scheme and target
* Set your team identity for code signing
* Create a file called `mapbox_access_token` in the root of the MapboxARKit project directory and write your [Mapbox Access Token](https://www.mapbox.com/studio/account/tokens/) in that file
* Install and run the app **on a device** (ARKit cannot run in the simulator)