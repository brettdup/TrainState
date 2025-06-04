struct CategoryManager {
    static let shared = CategoryManager()
    
    let categories: [String: [String]] = [
        "Push": ["Chest", "Shoulders", "Triceps"],
        "Pull": ["Back", "Biceps", "Rear Delts"],
        "Legs": ["Quads", "Hamstrings", "Calves"]
    ]
    
    private let subcategoryToParentMap: [String: String]

    // Helper method to get all subcategories
    func getAllSubcategories() -> [String] {
        return categories.values.flatMap { $0 }
    }
    
    // Helper method to find the parent category for a subcategory
    func getParentCategory(for subcategory: String) -> String? {
        return subcategoryToParentMap[subcategory]
    }
    
    private init() { // Private initializer to ensure singleton pattern
        var map: [String: String] = [:]
        for (parent, subs) in categories {
            for sub in subs {
                map[sub] = parent
            }
        }
        self.subcategoryToParentMap = map
    }
} 