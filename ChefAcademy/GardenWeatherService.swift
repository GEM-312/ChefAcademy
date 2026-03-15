//
//  GardenWeatherService.swift
//  ChefAcademy
//
//  Fetches real weather using Apple WeatherKit and ties it to garden growth!
//  Sunny days help plants grow faster, rainy days water them automatically.
//

import SwiftUI
import WeatherKit
import CoreLocation
import Combine

// MARK: - Garden Weather Enum

enum GardenWeather: String, CaseIterable {
    case sunny
    case partlyCloudy
    case cloudy
    case rainy
    case stormy
    case snowy
    case windy

    /// How much this weather speeds up or slows down plant growth
    var growthMultiplier: Double {
        switch self {
        case .sunny:        return 1.2   // 20% faster — sunshine helps!
        case .partlyCloudy: return 1.1   // 10% faster
        case .cloudy:       return 1.0   // Normal speed
        case .rainy:        return 1.0   // Normal, but auto-waters plants
        case .stormy:       return 0.9   // 10% slower — plants hiding from storm
        case .snowy:        return 0.85  // 15% slower — brr!
        case .windy:        return 0.95  // 5% slower
        }
    }

    /// Kid-friendly name for display
    var displayName: String {
        switch self {
        case .sunny:        return "Sunny"
        case .partlyCloudy: return "Partly Cloudy"
        case .cloudy:       return "Cloudy"
        case .rainy:        return "Rainy"
        case .stormy:       return "Stormy"
        case .snowy:        return "Snowy"
        case .windy:        return "Windy"
        }
    }

    /// SF Symbol for the weather badge
    var systemIcon: String {
        switch self {
        case .sunny:        return "sun.max.fill"
        case .partlyCloudy: return "cloud.sun.fill"
        case .cloudy:       return "cloud.fill"
        case .rainy:        return "cloud.rain.fill"
        case .stormy:       return "cloud.bolt.rain.fill"
        case .snowy:        return "cloud.snow.fill"
        case .windy:        return "wind"
        }
    }

    /// Icon color tint
    var iconColor: Color {
        switch self {
        case .sunny:        return .yellow
        case .partlyCloudy: return .orange
        case .cloudy:       return .gray
        case .rainy:        return .blue
        case .stormy:       return .purple
        case .snowy:        return .cyan
        case .windy:        return Color.AppTheme.sage
        }
    }

    /// Pip's weather-specific gardening tips
    var pipMessages: [String] {
        switch self {
        case .sunny:
            return [
                "What a sunny day! Your plants are loving it!",
                "The sun is shining — perfect gardening weather!",
                "Sunshine helps plants grow big and strong!"
            ]
        case .partlyCloudy:
            return [
                "A few clouds today, but your plants are happy!",
                "Some clouds are giving your plants a nice break from the sun."
            ]
        case .cloudy:
            return [
                "Clouds today, but plants still grow!",
                "A cozy cloudy day in the garden!"
            ]
        case .rainy:
            return [
                "Rain is watering your garden for free!",
                "Splish splash! The rain is great for your veggies!",
                "Plants love rain — nature's sprinkler!"
            ]
        case .stormy:
            return [
                "Whoa, a storm! Don't worry, your plants are safe!",
                "Thunder and lightning — nature's fireworks!",
                "Storms bring lots of water for the soil!"
            ]
        case .snowy:
            return [
                "Brrr! Snow is like a blanket for the soil!",
                "Even in the cold, your plants are tough!",
                "Snow melts into water for your garden later!"
            ]
        case .windy:
            return [
                "Whoosh! The wind is blowing today!",
                "Hold onto your hat — it's windy!",
                "Wind helps spread seeds around the garden!"
            ]
        }
    }
}

// MARK: - Rain Event Notification
extension Notification.Name {
    static let gardenRainEvent = Notification.Name("gardenRainEvent")
}

// MARK: - Garden Weather Service

class GardenWeatherService: NSObject, ObservableObject, CLLocationManagerDelegate {
    static let shared = GardenWeatherService()

    // Published state
    @Published var currentWeather: GardenWeather = .sunny
    @Published var temperature: Int = 72  // Fahrenheit
    @Published var temperatureCelsius: Int = 22
    @Published var locationStatus: CLAuthorizationStatus = .notDetermined
    @Published var isLoading: Bool = false

    /// When it last rained — used to decide if plants need watering
    @Published var lastRainDate: Date? {
        didSet {
            if let date = lastRainDate {
                UserDefaults.standard.set(date, forKey: lastRainKey)
            }
        }
    }

    // Private
    private let locationManager = CLLocationManager()
    private let weatherKitService = WeatherKit.WeatherService.shared
    private var lastFetchDate: Date?
    private var refreshTimer: Timer?
    private var currentLocation: CLLocation?

    // Cache keys
    private let cachedWeatherKey = "com.chefacademy.cachedWeather"
    private let cachedTempKey = "com.chefacademy.cachedTemperature"
    private let cachedTempCKey = "com.chefacademy.cachedTemperatureC"
    private let cachedTimestampKey = "com.chefacademy.cachedWeatherTimestamp"
    private let lastRainKey = "com.chefacademy.lastRainDate"

    /// How long to cache weather before refreshing (30 minutes)
    private let cacheInterval: TimeInterval = 1800

    // MARK: - Init

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyKilometer // Coarse is fine for weather
        loadCachedWeather()
    }

    // MARK: - Public API

    /// Request location permission — call once on first garden visit
    func requestLocationPermission() {
        locationManager.requestWhenInUseAuthorization()
    }

    /// Fetch weather (checks cache first)
    @MainActor
    func fetchWeather() async {
        // Check cache freshness
        if let lastFetch = lastFetchDate,
           Date().timeIntervalSince(lastFetch) < cacheInterval {
            return // Cache is still fresh
        }

        guard let location = currentLocation else {
            // No location yet — try requesting
            locationManager.requestLocation()
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            let weather = try await weatherKitService.weather(for: location)
            let condition = weather.currentWeather.condition
            let tempF = Int(weather.currentWeather.temperature.converted(to: .fahrenheit).value)
            let tempC = Int(weather.currentWeather.temperature.converted(to: .celsius).value)

            let mapped = mapCondition(condition)

            // Check if it's raining
            let oldWeather = currentWeather
            currentWeather = mapped
            temperature = tempF
            temperatureCelsius = tempC
            lastFetchDate = Date()

            // Cache it
            cacheWeather(mapped, tempF: tempF, tempC: tempC)

            // If weather changed to rain, notify garden
            if (mapped == .rainy || mapped == .stormy) && oldWeather != .rainy && oldWeather != .stormy {
                lastRainDate = Date()
                NotificationCenter.default.post(name: .gardenRainEvent, object: nil)
            }

            print("[Weather] Updated: \(mapped.displayName), \(tempF)°F / \(tempC)°C")
        } catch {
            print("[Weather] WeatherKit error: \(error.localizedDescription). Using cached/default.")
            // Fallback: keep current (cached or sunny default)
        }
    }

    /// Start periodic weather refresh (every 30 minutes)
    func startPeriodicRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: cacheInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.fetchWeather()
            }
        }
    }

    /// Stop the refresh timer
    func stopPeriodicRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    /// How long since it last rained (in seconds). Returns large value if never rained.
    var timeSinceLastRain: TimeInterval {
        guard let lastRain = lastRainDate else { return 86400 } // 24 hours if unknown
        return Date().timeIntervalSince(lastRain)
    }

    // MARK: - CLLocationManagerDelegate

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        currentLocation = location

        // Fetch weather with new location
        Task { @MainActor in
            await fetchWeather()
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("[Weather] Location error: \(error.localizedDescription). Using default sunny weather.")
        // Keep sunny default — never punish the kid
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        locationStatus = manager.authorizationStatus

        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            locationManager.requestLocation()
        case .denied, .restricted:
            print("[Weather] Location denied. Defaulting to sunny.")
            // Sunny default stays — kid never notices
        case .notDetermined:
            break // Wait for user response
        @unknown default:
            break
        }
    }

    // MARK: - Private Helpers

    /// Map Apple's WeatherCondition to our kid-friendly GardenWeather
    private func mapCondition(_ condition: WeatherCondition) -> GardenWeather {
        switch condition {
        case .clear, .hot, .mostlyClear:
            return .sunny
        case .partlyCloudy:
            return .partlyCloudy
        case .cloudy, .mostlyCloudy, .haze, .smoky, .foggy:
            return .cloudy
        case .rain, .drizzle, .heavyRain, .freezingRain, .freezingDrizzle:
            return .rainy
        case .thunderstorms, .strongStorms, .tropicalStorm, .hurricane:
            return .stormy
        case .snow, .heavySnow, .flurries, .sleet, .blizzard, .blowingSnow,
             .frigid, .wintryMix, .hail:
            return .snowy
        case .windy, .breezy, .blowingDust:
            return .windy
        default:
            return .sunny // Default to positive!
        }
    }

    /// Cache weather to UserDefaults
    private func cacheWeather(_ weather: GardenWeather, tempF: Int, tempC: Int) {
        UserDefaults.standard.set(weather.rawValue, forKey: cachedWeatherKey)
        UserDefaults.standard.set(tempF, forKey: cachedTempKey)
        UserDefaults.standard.set(tempC, forKey: cachedTempCKey)
        UserDefaults.standard.set(Date(), forKey: cachedTimestampKey)
    }

    /// Load cached weather on init
    private func loadCachedWeather() {
        if let raw = UserDefaults.standard.string(forKey: cachedWeatherKey),
           let cached = GardenWeather(rawValue: raw) {
            currentWeather = cached
        }
        let cachedTemp = UserDefaults.standard.integer(forKey: cachedTempKey)
        if cachedTemp != 0 { temperature = cachedTemp }
        let cachedTempC = UserDefaults.standard.integer(forKey: cachedTempCKey)
        if cachedTempC != 0 { temperatureCelsius = cachedTempC }

        if let rainDate = UserDefaults.standard.object(forKey: lastRainKey) as? Date {
            lastRainDate = rainDate
        }

        if let timestamp = UserDefaults.standard.object(forKey: cachedTimestampKey) as? Date {
            lastFetchDate = timestamp
        }
    }
}
