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

// MARK: - Garden Season

enum GardenSeason: String, CaseIterable {
    case spring, summer, fall, winter

    /// Determine season from current date + hemisphere
    static func current(latitude: Double? = nil) -> GardenSeason {
        let month = Calendar.current.component(.month, from: Date())
        let isSouthern = (latitude ?? 40) < 0  // Default to northern hemisphere

        let northernSeason: GardenSeason = {
            switch month {
            case 3, 4, 5:   return .spring
            case 6, 7, 8:   return .summer
            case 9, 10, 11: return .fall
            default:         return .winter
            }
        }()

        // Southern hemisphere is 6 months offset
        if isSouthern {
            switch northernSeason {
            case .spring: return .fall
            case .summer: return .winter
            case .fall:   return .spring
            case .winter: return .summer
            }
        }
        return northernSeason
    }

    var displayName: String {
        switch self {
        case .spring: return "Spring"
        case .summer: return "Summer"
        case .fall:   return "Fall"
        case .winter: return "Winter"
        }
    }

    var emoji: String {
        switch self {
        case .spring: return "🌸"
        case .summer: return "☀️"
        case .fall:   return "🍂"
        case .winter: return "❄️"
        }
    }

    /// Gradient colors for the seasonal overlay (top → bottom, subtle)
    var gradientColors: [Color] {
        switch self {
        case .spring:
            return [
                Color(hex: "E8F5E9").opacity(0.25),  // Soft green
                Color(hex: "FCE4EC").opacity(0.15),  // Cherry blossom pink
                Color.clear
            ]
        case .summer:
            return [
                Color(hex: "FFF8E1").opacity(0.2),   // Warm golden
                Color(hex: "FFF3E0").opacity(0.1),   // Light amber
                Color.clear
            ]
        case .fall:
            return [
                Color(hex: "FBE9E7").opacity(0.3),   // Warm orange tint
                Color(hex: "EFEBE9").opacity(0.2),   // Light brown
                Color(hex: "FFF8E1").opacity(0.1)    // Golden bottom
            ]
        case .winter:
            return [
                Color(hex: "E3F2FD").opacity(0.3),   // Icy blue
                Color(hex: "F3E5F5").opacity(0.15),  // Frosty lavender
                Color(hex: "ECEFF1").opacity(0.2)    // Cold grey
            ]
        }
    }

    /// Pip tip about the season
    var pipTip: String {
        switch self {
        case .spring: return "It's spring! Perfect time to plant leafy greens and herbs."
        case .summer: return "Summer sunshine! Tomatoes, peppers, and berries grow super fast now."
        case .fall:   return "Fall is here! Root veggies love this cool weather. Time to harvest!"
        case .winter: return "Brrr, it's winter! Plants grow slower, but root veggies are still happy."
        }
    }
}

// MARK: - Garden Weather Service

class GardenWeatherService: NSObject, ObservableObject, CLLocationManagerDelegate {
    static let shared = GardenWeatherService()

    // Published state
    @Published var currentWeather: GardenWeather = .sunny
    @Published var currentSeason: GardenSeason = GardenSeason.current()
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
            print("[Weather] Cache still fresh (\(Int(Date().timeIntervalSince(lastFetch)))s old). Skipping fetch.")
            return
        }

        guard let location = currentLocation else {
            print("[Weather] No location available yet — requesting location...")
            locationManager.requestLocation()
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            print("[Weather] Calling WeatherKit API for location: \(location.coordinate.latitude), \(location.coordinate.longitude)")
            let weather = try await weatherKitService.weather(for: location)
            let condition = weather.currentWeather.condition
            let tempF = Int(weather.currentWeather.temperature.converted(to: .fahrenheit).value)
            let tempC = Int(weather.currentWeather.temperature.converted(to: .celsius).value)

            print("[Weather] WeatherKit SUCCESS! Condition: \(condition), Temp: \(tempF)°F")
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
            print("[Weather] WeatherKit FAILED: \(error)")
            print("[Weather] Error description: \(error.localizedDescription)")
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
        guard let location = locations.last else {
            print("[Weather] didUpdateLocations called but no locations!")
            return
        }
        print("[Weather] Got location: \(location.coordinate.latitude), \(location.coordinate.longitude)")
        currentLocation = location

        // Update season based on hemisphere
        currentSeason = GardenSeason.current(latitude: location.coordinate.latitude)

        // Fetch weather with new location
        Task { @MainActor in
            await fetchWeather()
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("[Weather] Location FAILED: \(error.localizedDescription)")
        // Keep sunny default — never punish the kid
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        locationStatus = manager.authorizationStatus

        print("[Weather] Authorization status changed: \(manager.authorizationStatus.rawValue)")
        // 0=notDetermined, 1=restricted, 2=denied, 3=authorizedAlways, 4=authorizedWhenInUse

        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            print("[Weather] Location authorized! Requesting location...")
            locationManager.requestLocation()
        case .denied, .restricted:
            print("[Weather] Location DENIED or RESTRICTED. Defaulting to sunny.")
        case .notDetermined:
            print("[Weather] Location not determined yet — waiting for user response.")
            break
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
