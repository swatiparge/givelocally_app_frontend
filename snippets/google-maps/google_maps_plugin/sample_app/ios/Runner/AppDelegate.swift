import Flutter
import UIKit
import GoogleMaps  // Required for Google Maps

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {

    // GOOGLE MAPS API KEY CONFIGURATION
    // Replace YOUR_API_KEY_HERE with your actual Google Maps API key
    // Get your key at: https://console.cloud.google.com/
    GMSServices.provideAPIKey("AIzaSyDo1Ff1v46Nivfj0KKbLdW4cCSgi-0cVBw")

    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
