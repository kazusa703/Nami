//
//  WeatherManager.swift
//  Nami
//
//  Weather data auto-capture using WeatherKit + CoreLocation
//

import Foundation
import CoreLocation
import WeatherKit
import SwiftUI

/// Manages weather data fetching using WeatherKit and CoreLocation
@Observable
@MainActor
final class WeatherManager: NSObject {

    // MARK: - State

    /// User preference to enable weather tracking
    var isEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: "weatherEnabled") }
        set {
            UserDefaults.standard.set(newValue, forKey: "weatherEnabled")
            if newValue && !isAuthorized {
                requestLocationPermission()
            }
        }
    }

    /// Whether location permission is granted
    var isAuthorized: Bool = false

    // MARK: - Private

    private let locationManager = CLLocationManager()
    private let weatherService = WeatherService.shared
    private var locationContinuation: CheckedContinuation<CLLocation?, Never>?

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyKilometer
        checkAuthorizationStatus()
    }

    // MARK: - Authorization

    /// Request location permission for weather data
    func requestLocationPermission() {
        locationManager.requestWhenInUseAuthorization()
    }

    /// Check current authorization status
    private func checkAuthorizationStatus() {
        let status = locationManager.authorizationStatus
        isAuthorized = (status == .authorizedWhenInUse || status == .authorizedAlways)
    }

    // MARK: - Weather Fetching

    /// Fetch current weather at user's location
    /// Returns (condition string, temperature in Celsius) or (nil, nil)
    func fetchCurrentWeather() async -> (condition: String?, temperature: Double?) {
        guard isEnabled, isAuthorized else { return (nil, nil) }

        // Get one-shot location
        guard let location = await requestCurrentLocation() else { return (nil, nil) }

        do {
            let weather = try await weatherService.weather(for: location)
            let current = weather.currentWeather
            let condition = mapCondition(current.condition)
            let temperature = current.temperature.value // Celsius by default
            return (condition, temperature)
        } catch {
            print("WeatherKit fetch error: \(error)")
            return (nil, nil)
        }
    }

    /// Request a one-shot location update
    private func requestCurrentLocation() async -> CLLocation? {
        return await withCheckedContinuation { continuation in
            self.locationContinuation = continuation
            locationManager.requestLocation()
        }
    }

    /// Map WeatherKit condition to simplified string
    private func mapCondition(_ condition: WeatherCondition) -> String {
        switch condition {
        case .clear, .mostlyClear, .hot:
            return "sunny"
        case .partlyCloudy, .mostlyCloudy, .cloudy:
            return "cloudy"
        case .rain, .heavyRain, .drizzle, .freezingRain, .freezingDrizzle:
            return "rainy"
        case .snow, .heavySnow, .flurries, .sleet, .blowingSnow, .wintryMix:
            return "snowy"
        case .thunderstorms, .strongStorms, .tropicalStorm, .hurricane:
            return "stormy"
        case .foggy, .haze, .smoky, .blowingDust:
            return "foggy"
        default:
            return "cloudy" // fallback
        }
    }
}

// MARK: - CLLocationManagerDelegate

extension WeatherManager: @preconcurrency CLLocationManagerDelegate {

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor in
            locationContinuation?.resume(returning: locations.first)
            locationContinuation = nil
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            print("Location error: \(error)")
            locationContinuation?.resume(returning: nil)
            locationContinuation = nil
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            checkAuthorizationStatus()
        }
    }
}

// MARK: - Environment Key

private struct WeatherManagerKey: @preconcurrency EnvironmentKey {
    @MainActor static let defaultValue = WeatherManager()
}

extension EnvironmentValues {
    var weatherManager: WeatherManager {
        get { self[WeatherManagerKey.self] }
        set { self[WeatherManagerKey.self] = newValue }
    }
}
