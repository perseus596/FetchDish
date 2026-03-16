import Foundation

/// Categorizes ingredients by grocery aisle using keyword matching.
enum IngredientCategorizer {

    /// Categories in display order — Meat and Seafood are adjacent.
    static let categories: [(name: String, keywords: [String])] = [
        ("Produce", [
            "lettuce", "tomato", "onion", "garlic", "pepper", "carrot", "celery",
            "potato", "broccoli", "spinach", "kale", "cucumber", "zucchini",
            "mushroom", "avocado", "lemon", "lime", "orange", "apple", "banana",
            "berry", "strawberry", "blueberry", "raspberry", "mango", "pineapple",
            "ginger", "cilantro", "parsley", "basil", "mint", "thyme", "rosemary",
            "sage", "dill", "chive", "scallion", "shallot", "leek", "corn",
            "pea", "cabbage", "cauliflower", "asparagus", "beet", "radish",
            "turnip", "squash", "pumpkin", "eggplant", "jalape", "serrano",
            "habanero", "arugula", "watercress", "endive", "fennel", "artichoke",
            "okra", "sweet potato", "yam", "plantain", "bok choy", "sprout",
            "snap pea", "snow pea", "green bean", "string bean",
        ]),
        ("Meat", [
            "chicken", "beef", "pork", "turkey", "lamb", "veal", "duck",
            "bacon", "sausage", "ham", "ground beef", "ground turkey",
            "steak", "roast", "rib", "thigh", "breast", "drumstick", "wing",
            "tenderloin", "chop", "loin", "prosciutto", "pancetta",
            "ground pork", "ground lamb", "ground chicken", "bison", "venison",
            "elk", "rabbit", "quail", "goose", "cornish hen", "pheasant",
            "filet mignon", "sirloin", "flank", "brisket", "skirt steak",
            "chuck", "short rib", "oxtail", "liver", "chorizo", "salami",
            "pepperoni", "mortadella", "bratwurst", "kielbasa", "hot dog",
            "deli meat", "pulled pork", "carnitas", "al pastor",
        ]),
        ("Seafood", [
            "salmon", "tuna", "shrimp", "cod", "tilapia", "halibut", "crab",
            "lobster", "scallop", "clam", "mussel", "oyster", "anchovy",
            "sardine", "trout", "bass", "swordfish", "mahi", "prawn", "fish",
            "snapper", "grouper", "catfish", "perch", "walleye", "pike",
            "flounder", "sole", "haddock", "pollock", "mackerel", "herring",
            "ahi", "yellowtail", "branzino", "sea bass", "monkfish",
            "squid", "calamari", "octopus", "crawfish", "crayfish", "langostine",
            "king crab", "snow crab", "ceviche", "surimi", "caviar",
        ]),
        ("Dairy & Eggs", [
            "milk", "cream", "butter", "cheese", "yogurt", "sour cream",
            "cream cheese", "whipped cream", "half-and-half", "buttermilk",
            "mozzarella", "parmesan", "cheddar", "ricotta", "feta", "gouda",
            "brie", "gruyere", "mascarpone", "cottage cheese", "egg",
        ]),
        ("Bakery", [
            "bread", "tortilla", "pita", "naan", "baguette", "roll",
            "bun", "croissant", "english muffin", "bagel", "crouton",
        ]),
        ("Pantry", [
            "flour", "sugar", "salt", "oil", "olive oil", "vegetable oil",
            "vinegar", "soy sauce", "worcestershire", "hot sauce", "ketchup",
            "mustard", "mayonnaise", "honey", "maple syrup", "vanilla",
            "baking powder", "baking soda", "yeast", "cornstarch", "cocoa",
            "chocolate", "rice", "pasta", "noodle", "quinoa", "oat",
            "breadcrumb", "panko", "broth", "stock", "tomato paste",
            "tomato sauce", "diced tomato", "crushed tomato", "coconut milk",
            "bean", "lentil", "chickpea", "peanut butter", "almond", "walnut",
            "pecan", "cashew", "pistachio", "sesame", "cumin", "paprika",
            "cinnamon", "nutmeg", "oregano", "chili powder", "curry",
            "turmeric", "coriander", "bay leaf", "red pepper flake",
            "garlic powder", "onion powder", "italian seasoning", "cajun",
            "pepper", "black pepper", "white pepper",
        ]),
        ("Frozen", [
            "frozen",
        ]),
        ("Beverages", [
            "wine", "beer", "juice", "coffee", "tea", "soda", "water",
        ]),
    ]

    /// Explicit display order for categories (matches array order above).
    static let displayOrder: [String] = categories.map { $0.name } + ["Other"]

    /// Returns the aisle category for an ingredient string.
    static func categorize(_ ingredient: String) -> String {
        let lower = ingredient.lowercased()
        for (name, keywords) in categories {
            for keyword in keywords {
                if lower.contains(keyword) {
                    return name
                }
            }
        }
        return "Other"
    }
}
