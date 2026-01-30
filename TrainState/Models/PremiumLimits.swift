import Foundation

/// Free tier limits for TrainState. Premium users have unlimited access.
enum PremiumLimits {
    /// Maximum workouts for free users.
    static let freeWorkoutLimit = 7

    /// Maximum main categories for free users.
    static let freeCategoryLimit = 3

    /// Maximum subcategories per category for free users.
    static let freeSubcategoryPerCategoryLimit = 2
}
