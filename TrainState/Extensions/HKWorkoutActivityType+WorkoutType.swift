import HealthKit

struct AppleWorkoutSelection: Hashable, Identifiable {
    let activityType: HKWorkoutActivityType
    let locationType: HKWorkoutSessionLocationType?

    var id: String {
        "\(activityType.rawValue)-\(locationType?.rawValue ?? 0)"
    }

    var displayName: String {
        activityType.displayName(locationType: locationType)
    }

    static func normalized(
        activityType: HKWorkoutActivityType,
        locationType: HKWorkoutSessionLocationType?
    ) -> AppleWorkoutSelection {
        if activityType.supportsLocationChoice {
            return AppleWorkoutSelection(
                activityType: activityType,
                locationType: locationType ?? .unknown
            )
        }

        return AppleWorkoutSelection(
            activityType: activityType,
            locationType: nil
        )
    }
}

extension HKWorkoutActivityType {
    var systemImage: String {
        switch self {
        case .running, .wheelchairRunPace:
            return "figure.run"
        case .walking, .hiking, .wheelchairWalkPace:
            return "figure.walk"
        case .cycling, .handCycling:
            return "bicycle"
        case .swimming, .waterFitness, .waterPolo, .waterSports, .underwaterDiving:
            return "figure.pool.swim"
        case .traditionalStrengthTraining, .functionalStrengthTraining, .coreTraining:
            return "dumbbell.fill"
        case .yoga, .pilates, .barre, .taiChi, .mindAndBody, .flexibility:
            return "figure.mind.and.body"
        case .rowing:
            return "figure.rower"
        case .elliptical:
            return "figure.elliptical"
        case .stairClimbing, .stairs, .stepTraining:
            return "figure.stair.stepper"
        case .highIntensityIntervalTraining, .mixedCardio, .mixedMetabolicCardioTraining, .cardioDance:
            return "heart.fill"
        case .cooldown, .preparationAndRecovery:
            return "figure.cooldown"
        case .soccer:
            return "soccerball"
        case .basketball:
            return "basketball.fill"
        case .tennis, .pickleball, .racquetball, .squash, .tableTennis, .badminton:
            return "tennis.racket"
        case .golf:
            return "figure.golf"
        case .americanFootball, .australianFootball, .rugby:
            return "football.fill"
        case .baseball, .softball:
            return "baseball.fill"
        case .volleyball:
            return "volleyball.fill"
        case .bowling:
            return "figure.bowling"
        case .boxing, .kickboxing, .martialArts, .wrestling:
            return "figure.boxing"
        case .climbing:
            return "figure.climbing"
        case .snowboarding, .downhillSkiing, .crossCountrySkiing, .snowSports:
            return "figure.snowboarding"
        case .skatingSports:
            return "figure.skating"
        case .surfingSports, .paddleSports, .sailing:
            return "figure.sailing"
        case .dance, .danceInspiredTraining, .socialDance:
            return "figure.dance"
        default:
            return mappedWorkoutType.systemImage
        }
    }

    static let allKnownCases: [HKWorkoutActivityType] = [
        .americanFootball, .archery, .australianFootball, .badminton, .baseball, .basketball,
        .bowling, .boxing, .climbing, .cricket, .crossTraining, .curling, .cycling, .dance,
        .danceInspiredTraining, .elliptical, .equestrianSports, .fencing, .fishing,
        .functionalStrengthTraining, .golf, .gymnastics, .handball, .hiking, .hockey,
        .hunting, .lacrosse, .martialArts, .mindAndBody, .mixedMetabolicCardioTraining,
        .paddleSports, .play, .preparationAndRecovery, .racquetball, .rowing, .rugby,
        .running, .sailing, .skatingSports, .snowSports, .soccer, .softball, .squash,
        .stairClimbing, .surfingSports, .swimming, .tableTennis, .tennis, .trackAndField,
        .traditionalStrengthTraining, .volleyball, .walking, .waterFitness, .waterPolo,
        .waterSports, .wrestling, .yoga, .barre, .coreTraining, .crossCountrySkiing,
        .downhillSkiing, .flexibility, .highIntensityIntervalTraining, .jumpRope,
        .kickboxing, .pilates, .snowboarding, .stairs, .stepTraining, .wheelchairWalkPace,
        .wheelchairRunPace, .taiChi, .mixedCardio, .handCycling, .discSports, .fitnessGaming,
        .cardioDance, .socialDance, .pickleball, .cooldown, .swimBikeRun, .transition,
        .underwaterDiving, .other
    ]

    var mappedWorkoutType: WorkoutType {
        switch self {
        case .running:
            return .running

        case .cycling, .handCycling:
            return .cycling

        case .swimming, .underwaterDiving:
            return .swimming

        case .yoga, .barre, .pilates, .taiChi, .flexibility, .mindAndBody, .cooldown, .preparationAndRecovery:
            return .yoga

        case .traditionalStrengthTraining, .functionalStrengthTraining, .coreTraining, .crossTraining:
            return .strength

        case .americanFootball,
             .archery,
             .australianFootball,
             .badminton,
             .baseball,
             .basketball,
             .bowling,
             .boxing,
             .climbing,
             .cricket,
             .curling,
             .dance,
             .danceInspiredTraining,
             .elliptical,
             .equestrianSports,
             .fencing,
             .fishing,
             .golf,
             .gymnastics,
             .handball,
             .hiking,
             .hockey,
             .hunting,
             .lacrosse,
             .martialArts,
             .mixedMetabolicCardioTraining,
             .paddleSports,
             .play,
             .racquetball,
             .rowing,
             .rugby,
             .sailing,
             .skatingSports,
             .snowSports,
             .soccer,
             .softball,
             .squash,
             .stairClimbing,
             .surfingSports,
             .tableTennis,
             .tennis,
             .trackAndField,
             .volleyball,
             .walking,
             .waterFitness,
             .waterPolo,
             .waterSports,
             .wrestling,
             .crossCountrySkiing,
             .downhillSkiing,
             .highIntensityIntervalTraining,
             .jumpRope,
             .kickboxing,
             .snowboarding,
             .stairs,
             .stepTraining,
             .wheelchairWalkPace,
             .wheelchairRunPace,
             .mixedCardio,
             .discSports,
             .fitnessGaming,
             .cardioDance,
             .socialDance,
             .pickleball,
             .swimBikeRun,
             .transition:
            return .cardio

        case .other:
            return .other

        @unknown default:
            return .other
        }
    }

    var displayName: String {
        switch self {
        case .americanFootball: return "American Football"
        case .archery: return "Archery"
        case .australianFootball: return "Australian Football"
        case .badminton: return "Badminton"
        case .baseball: return "Baseball"
        case .basketball: return "Basketball"
        case .bowling: return "Bowling"
        case .boxing: return "Boxing"
        case .climbing: return "Climbing"
        case .cricket: return "Cricket"
        case .crossTraining: return "Cross Training"
        case .curling: return "Curling"
        case .cycling: return "Cycling"
        case .dance: return "Dance"
        case .danceInspiredTraining: return "Dance Inspired Training"
        case .elliptical: return "Elliptical"
        case .equestrianSports: return "Equestrian Sports"
        case .fencing: return "Fencing"
        case .fishing: return "Fishing"
        case .functionalStrengthTraining: return "Functional Strength Training"
        case .golf: return "Golf"
        case .gymnastics: return "Gymnastics"
        case .handball: return "Handball"
        case .hiking: return "Hiking"
        case .hockey: return "Hockey"
        case .hunting: return "Hunting"
        case .lacrosse: return "Lacrosse"
        case .martialArts: return "Martial Arts"
        case .mindAndBody: return "Mind and Body"
        case .mixedMetabolicCardioTraining: return "Mixed Metabolic Cardio Training"
        case .paddleSports: return "Paddle Sports"
        case .play: return "Play"
        case .preparationAndRecovery: return "Preparation and Recovery"
        case .racquetball: return "Racquetball"
        case .rowing: return "Rowing"
        case .rugby: return "Rugby"
        case .running: return "Running"
        case .sailing: return "Sailing"
        case .skatingSports: return "Skating Sports"
        case .snowSports: return "Snow Sports"
        case .soccer: return "Soccer"
        case .softball: return "Softball"
        case .squash: return "Squash"
        case .stairClimbing: return "Stair Climbing"
        case .surfingSports: return "Surfing Sports"
        case .swimming: return "Swimming"
        case .tableTennis: return "Table Tennis"
        case .tennis: return "Tennis"
        case .trackAndField: return "Track and Field"
        case .traditionalStrengthTraining: return "Traditional Strength Training"
        case .volleyball: return "Volleyball"
        case .walking: return "Walking"
        case .waterFitness: return "Water Fitness"
        case .waterPolo: return "Water Polo"
        case .waterSports: return "Water Sports"
        case .wrestling: return "Wrestling"
        case .yoga: return "Yoga"
        case .barre: return "Barre"
        case .coreTraining: return "Core Training"
        case .crossCountrySkiing: return "Cross Country Skiing"
        case .downhillSkiing: return "Downhill Skiing"
        case .flexibility: return "Flexibility"
        case .highIntensityIntervalTraining: return "High Intensity Interval Training"
        case .jumpRope: return "Jump Rope"
        case .kickboxing: return "Kickboxing"
        case .pilates: return "Pilates"
        case .snowboarding: return "Snowboarding"
        case .stairs: return "Stairs"
        case .stepTraining: return "Step Training"
        case .wheelchairWalkPace: return "Wheelchair Walk Pace"
        case .wheelchairRunPace: return "Wheelchair Run Pace"
        case .taiChi: return "Tai Chi"
        case .mixedCardio: return "Mixed Cardio"
        case .handCycling: return "Hand Cycling"
        case .discSports: return "Disc Sports"
        case .fitnessGaming: return "Fitness Gaming"
        case .cardioDance: return "Cardio Dance"
        case .socialDance: return "Social Dance"
        case .pickleball: return "Pickleball"
        case .cooldown: return "Cooldown"
        case .swimBikeRun: return "Swim Bike Run"
        case .transition: return "Transition"
        case .underwaterDiving: return "Underwater Diving"
        case .other: return "Other"
        @unknown default: return "Other"
        }
    }
}

extension HKWorkoutSessionLocationType {
    var displayName: String {
        switch self {
        case .indoor: return "Indoor"
        case .outdoor: return "Outdoor"
        case .unknown: return "Unspecified"
        @unknown default: return "Unspecified"
        }
    }
}

extension WorkoutType {
    var defaultAppleWorkoutActivityType: HKWorkoutActivityType {
        switch self {
        case .strength: return .traditionalStrengthTraining
        case .cardio: return .mixedCardio
        case .yoga: return .yoga
        case .running: return .running
        case .cycling: return .cycling
        case .swimming: return .swimming
        case .other: return .other
        }
    }

    var appleWorkoutActivityOptions: [AppleWorkoutSelection] {
        HKWorkoutActivityType.allKnownCases
            .flatMap(\.pickerSelections)
            .sorted { $0.displayName < $1.displayName }
    }
}

extension HKWorkoutActivityType {
    var supportsLocationChoice: Bool {
        switch self {
        case .running, .walking, .hiking, .cycling, .handCycling, .wheelchairWalkPace, .wheelchairRunPace:
            return true
        default:
            return false
        }
    }

    func displayName(locationType: HKWorkoutSessionLocationType?) -> String {
        guard let locationType, locationType != .unknown, supportsLocationChoice else {
            return displayName
        }
        return "\(locationType.displayName) \(displayName)"
    }

    var pickerSelections: [AppleWorkoutSelection] {
        guard supportsLocationChoice else {
            return [AppleWorkoutSelection(activityType: self, locationType: nil)]
        }

        return [
            AppleWorkoutSelection(activityType: self, locationType: .indoor),
            AppleWorkoutSelection(activityType: self, locationType: .outdoor),
            AppleWorkoutSelection(activityType: self, locationType: .unknown)
        ]
    }
}
