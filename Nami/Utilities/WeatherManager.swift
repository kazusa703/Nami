//
//  WeatherManager.swift
//  Nami
//
//  天気データの取得・管理
//

import Foundation
import CoreLocation
import WeatherKit

/// 天気データを取得してMoodEntryに付与するマネージャー
@Observable
class WeatherManager: NSObject {
    private let locationManager = CLLocationManager()
    private let weatherService = WeatherService.shared

    /// Access must be serialized on @MainActor to prevent race conditions
    @MainActor
    private var locationContinuation: CheckedContinuation<CLLocation?, Never>?

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    /// 位置情報の許可状態
    var authorizationStatus: CLAuthorizationStatus {
        locationManager.authorizationStatus
    }

    /// 位置情報の許可をリクエスト
    func requestLocationPermission() {
        locationManager.requestWhenInUseAuthorization()
    }

    /// 現在地の天気データをエントリに付与する
    @MainActor
    func attachWeatherData(to entry: MoodEntry) async {
        do {
            // 位置情報を取得
            guard let location = await requestCurrentLocation() else { return }

            entry.latitude = location.coordinate.latitude
            entry.longitude = location.coordinate.longitude

            // WeatherKitで天気を取得
            let weather = try await weatherService.weather(for: location)
            let current = weather.currentWeather

            entry.weatherCondition = mapCondition(current.condition)
            entry.weatherTemperature = current.temperature.converted(to: .celsius).value
            entry.weatherPressure = current.pressure.converted(to: .hectopascals).value
            entry.weatherHumidity = current.humidity * 100
        } catch {
            // 天気取得失敗は記録を妨げない
            #if DEBUG
            print("WeatherManager: 天気取得エラー: \(error)")
            #endif
        }
    }

    /// 現在地を非同期で取得（タイムアウト付き）
    @MainActor
    private func requestCurrentLocation() async -> CLLocation? {
        let status = locationManager.authorizationStatus
        guard status == .authorizedWhenInUse || status == .authorizedAlways else { return nil }

        // Already requesting — skip to prevent double continuation resume
        guard locationContinuation == nil else { return nil }

        return await withCheckedContinuation { continuation in
            self.locationContinuation = continuation
            self.locationManager.requestLocation()

            // Timeout after 10 seconds to prevent hanging
            DispatchQueue.main.asyncAfter(deadline: .now() + 10) { [weak self] in
                guard let self, let cont = self.locationContinuation else { return }
                self.locationContinuation = nil
                cont.resume(returning: nil)
            }
        }
    }

    /// WeatherCondition → 日本語マッピング
    private func mapCondition(_ condition: WeatherCondition) -> String {
        switch condition {
        case .clear:                    return "晴れ"
        case .mostlyClear:              return "ほぼ晴れ"
        case .partlyCloudy:             return "やや曇り"
        case .mostlyCloudy:             return "ほぼ曇り"
        case .cloudy:                   return "曇り"
        case .rain:                     return "雨"
        case .heavyRain:                return "大雨"
        case .drizzle:                  return "小雨"
        case .snow:                     return "雪"
        case .heavySnow:                return "大雪"
        case .sleet:                    return "みぞれ"
        case .thunderstorms:            return "雷雨"
        case .tropicalStorm:            return "台風"
        case .hurricane:                return "暴風雨"
        case .foggy:                    return "霧"
        case .haze:                     return "もや"
        case .smoky:                    return "煙霧"
        case .windy:                    return "強風"
        case .breezy:                   return "微風"
        case .blowingDust:              return "砂塵"
        case .frigid:                   return "極寒"
        case .hot:                      return "猛暑"
        case .hail:                     return "ひょう"
        case .sunShowers:               return "天気雨"
        case .freezingRain:             return "凍雨"
        case .freezingDrizzle:          return "凍霧雨"
        case .blizzard:                 return "吹雪"
        case .blowingSnow:              return "地吹雪"
        case .wintryMix:                return "冬の嵐"
        case .isolatedThunderstorms:    return "局地雷雨"
        case .scatteredThunderstorms:   return "散発雷雨"
        case .strongStorms:             return "激しい嵐"
        case .sunFlurries:              return "晴れ時々雪"
        case .flurries:                 return "にわか雪"
        @unknown default:               return "不明"
        }
    }
}

// MARK: - CLLocationManagerDelegate

extension WeatherManager: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor in
            guard let cont = locationContinuation else { return }
            locationContinuation = nil
            cont.resume(returning: locations.first)
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            guard let cont = locationContinuation else { return }
            locationContinuation = nil
            cont.resume(returning: nil)
        }
    }
}
