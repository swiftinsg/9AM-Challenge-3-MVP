//
//  NearMeFilter.swift
//  9AM Challenge 3 MVP
//
//  Location permission and status text for weekly recommendations. Selecting
//  "Near Me" in the region filter sorts the current picks by distance; dietary
//  preferences are still respected.
//

import SwiftUI
import Combine
import CoreLocation

@MainActor
final class UserLocationProvider: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published private(set) var location: CLLocation?
    @Published private(set) var status: CLAuthorizationStatus = .notDetermined
    @Published private(set) var message: String?

    private let manager = CLLocationManager()

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        status = manager.authorizationStatus
    }

    func requestLocation() {
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            message = nil
            manager.requestLocation()
        case .denied, .restricted:
            location = nil
            message = "Enable Location in Settings to find spots near you."
        @unknown default:
            break
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            let newStatus = self.manager.authorizationStatus
            self.status = newStatus
            switch newStatus {
            case .authorizedWhenInUse, .authorizedAlways:
                self.message = nil
                self.manager.requestLocation()
            case .denied, .restricted:
                self.location = nil
                self.message = "Enable Location in Settings to find spots near you."
            default:
                break
            }
        }
    }

    nonisolated func locationManager(
        _ manager: CLLocationManager,
        didUpdateLocations locations: [CLLocation]
    ) {
        let latitude = locations.last?.coordinate.latitude
        let longitude = locations.last?.coordinate.longitude
        Task { @MainActor in
            if let latitude, let longitude {
                self.location = CLLocation(latitude: latitude, longitude: longitude)
            }
            self.message = nil
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            self.message = "Couldn't find your location. Try again."
        }
    }
}

struct NearMeStatusMessage: View {
    @ObservedObject var location: UserLocationProvider

    var body: some View {
        if location.location == nil {
            Text(location.message ?? "Finding your location…")
                .font(.dynaPuff(12))
                .foregroundStyle(AppColor.secondaryText)
        }
    }
}
