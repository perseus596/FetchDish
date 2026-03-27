import Foundation

struct IngredientWeightEntry {
    let name: String
    let volumeMl: Double
    let grams: Double

    init(_ name: String, _ volumeMl: Double, _ grams: Double) {
        self.name = name
        self.volumeMl = volumeMl
        self.grams = grams
    }

    var gramsPerMl: Double { grams / volumeMl }
}

enum IngredientWeightDatabase {

    static let entries: [IngredientWeightEntry] = {
        let c1    = 236.588   // 1 cup
        let c12   = 118.294   // 1/2 cup
        let c14   = 59.147    // 1/4 cup
        let c13   = 78.863    // 1/3 cup
        let tb1   = 14.787    // 1 tablespoon
        let tb2   = 29.574    // 2 tablespoons
        let ts1   = 4.929     // 1 teaspoon
        let ts2   = 9.858     // 2 teaspoons
        let ts12  = 2.464     // 1/2 teaspoon
        let c4    = 946.353   // 4 cups

        return [
            // A
            IngredientWeightEntry("'00' Pizza Flour",              c1,   116),
            IngredientWeightEntry("Agave Syrup",                   c14,   84),
            IngredientWeightEntry("All-Purpose Baking Mix",        c1,   120),
            IngredientWeightEntry("All-Purpose Flour",             c1,   120),
            IngredientWeightEntry("Almond Butter",                 c14,   68),
            IngredientWeightEntry("Almond Flour",                  c1,    96),
            IngredientWeightEntry("Almond Meal",                   c1,    84),
            IngredientWeightEntry("Almond Paste (packed)",         c1,   259),
            IngredientWeightEntry("Almonds (sliced)",              c12,   43),
            IngredientWeightEntry("Almonds (slivered)",            c12,   57),
            IngredientWeightEntry("Almonds (whole)",               c1,   142),
            IngredientWeightEntry("Amaranth Flour",                c1,   103),
            IngredientWeightEntry("Apple Juice Concentrate",       c14,   70),
            IngredientWeightEntry("Apples (dried, diced)",         c1,    85),
            IngredientWeightEntry("Apples (peeled, sliced)",       c1,   113),
            IngredientWeightEntry("Applesauce",                    c1,   255),
            IngredientWeightEntry("Apricots (dried, diced)",       c12,   64),
            IngredientWeightEntry("Artisan Bread Flour",           c1,   120),

            // B
            IngredientWeightEntry("Baker's Cinnamon Filling",      c1,   152),
            IngredientWeightEntry("Baker's Fruit Blend",           c1,   128),
            IngredientWeightEntry("Baker's Special Sugar",         c1,   190),
            IngredientWeightEntry("Baking Powder",                 ts1,    4),
            IngredientWeightEntry("Baking Soda",                   ts12,   3),
            IngredientWeightEntry("Baking Sugar Alternative",      c1,   170),
            IngredientWeightEntry("Bananas (mashed)",              c1,   227),
            IngredientWeightEntry("Barley (cooked)",               c1,   215),
            IngredientWeightEntry("Barley (pearled)",              c1,   213),
            IngredientWeightEntry("Barley Flakes",                 c12,   46),
            IngredientWeightEntry("Barley Flour",                  c1,    85),
            IngredientWeightEntry("Barley Malt Syrup",             tb2,   42),
            IngredientWeightEntry("Basil Pesto",                   tb2,   28),
            IngredientWeightEntry("Bell Peppers (fresh)",          c1,   142),
            IngredientWeightEntry("Berries (frozen)",              c1,   142),
            IngredientWeightEntry("Blueberries (dried)",           c1,   156),
            IngredientWeightEntry("Blueberries (fresh or frozen)", c1,   155),
            IngredientWeightEntry("Blueberry Juice",               c1,   241),
            IngredientWeightEntry("Boiled Cider",                  c14,   85),
            IngredientWeightEntry("Bran Cereal",                   c1,    60),
            IngredientWeightEntry("Bread Flour",                   c1,   120),
            IngredientWeightEntry("Breadcrumbs (dried)",           c14,   28),
            IngredientWeightEntry("Breadcrumbs (fresh)",           c14,   21),
            IngredientWeightEntry("Breadcrumbs (Panko)",           c1,    50),
            IngredientWeightEntry("Brown Rice (cooked)",           c1,   170),
            IngredientWeightEntry("Brown Rice Flour",              c1,   128),
            IngredientWeightEntry("Brown Sugar (packed)",          c1,   213),
            IngredientWeightEntry("Buckwheat (whole)",             c1,   170),
            IngredientWeightEntry("Buckwheat Flour",               c1,   120),
            IngredientWeightEntry("Bulgur",                        c1,   152),
            IngredientWeightEntry("Butter",                        c12,  113),
            IngredientWeightEntry("Buttermilk",                    c1,   227),
            IngredientWeightEntry("Buttermilk Biscuit Flour Blend",c1,   110),
            IngredientWeightEntry("Buttermilk Powder",             tb2,   18),

            // C
            IngredientWeightEntry("Cacao Nibs",                    c1,   120),
            IngredientWeightEntry("Cake Enhancer",                 tb2,   14),
            IngredientWeightEntry("Candied Lemon Peel",            c14,   37),
            IngredientWeightEntry("Candied Orange Peel",           c14,   25),
            IngredientWeightEntry("Caramel Bits",                  c1,   156),
            IngredientWeightEntry("Caraway Seeds",                 tb2,   18),
            IngredientWeightEntry("Carrots (cooked, puréed)",      c12,  128),
            IngredientWeightEntry("Carrots (diced)",               c1,   142),
            IngredientWeightEntry("Carrots (grated)",              c1,    99),
            IngredientWeightEntry("Cashews (chopped)",             c1,   113),
            IngredientWeightEntry("Cashews (whole)",               c1,   113),
            IngredientWeightEntry("Celery (diced)",                c1,   142),
            IngredientWeightEntry("Cheese (Feta)",                 c12,   57),
            IngredientWeightEntry("Cheese (grated Cheddar)",       c1,   113),
            IngredientWeightEntry("Cheese (grated Mozzarella)",    c1,   113),
            IngredientWeightEntry("Cheese (grated Parmesan)",      c12,   50),
            IngredientWeightEntry("Cheese (Ricotta)",              c1,   227),
            IngredientWeightEntry("Cherries (candied)",            c14,   50),
            IngredientWeightEntry("Cherries (dried)",              c12,   71),
            IngredientWeightEntry("Cherries (fresh, pitted)",      c12,   80),
            IngredientWeightEntry("Cherries (frozen)",             c1,   113),
            IngredientWeightEntry("Cherry Concentrate",            tb2,   42),
            IngredientWeightEntry("Chia Seeds",                    c14,   37),
            IngredientWeightEntry("Chickpea Flour",                c1,    85),
            IngredientWeightEntry("Chives (fresh)",                c12,   21),
            IngredientWeightEntry("Chocolate (chopped)",           c1,   170),
            IngredientWeightEntry("Chocolate Chips",               c1,   170),
            IngredientWeightEntry("Chocolate Chunks",              c1,   170),
            IngredientWeightEntry("Cinnamon-Sugar",                c14,   50),
            IngredientWeightEntry("Cocoa (unsweetened)",           c12,   42),
            IngredientWeightEntry("Coconut (sweetened, shredded)", c1,    85),
            IngredientWeightEntry("Coconut (unsweetened, shredded)",c1,   53),
            IngredientWeightEntry("Coconut (unsweetened, flakes)", c1,    60),
            IngredientWeightEntry("Coconut Cream",                 c1,   284),
            IngredientWeightEntry("Coconut Flour",                 c1,   128),
            IngredientWeightEntry("Coconut Milk (canned)",         c1,   241),
            IngredientWeightEntry("Coconut Milk (evaporated)",     c1,   242),
            IngredientWeightEntry("Coconut Milk Powder",           c12,   57),
            IngredientWeightEntry("Coconut Oil",                   c12,  113),
            IngredientWeightEntry("Coconut Sugar",                 c12,   77),
            IngredientWeightEntry("Confectioners' Sugar",          c1,   113),
            IngredientWeightEntry("Cookie Butter",                 c14,   72),
            IngredientWeightEntry("Cookie Crumbs",                 c1,    85),
            IngredientWeightEntry("Corn (fresh or frozen)",        c14,   38),
            IngredientWeightEntry("Corn (popped)",                 c4,    21),
            IngredientWeightEntry("Corn Syrup",                    c1,   312),
            IngredientWeightEntry("Cornmeal",                      c1,   138),
            IngredientWeightEntry("Cornstarch",                    c14,   28),
            IngredientWeightEntry("Cottage Cheese",                c12,  113),
            IngredientWeightEntry("Cracked Wheat",                 c1,   149),
            IngredientWeightEntry("Cranberries (dried)",           c12,   57),
            IngredientWeightEntry("Cranberries (fresh or frozen)", c1,    99),
            IngredientWeightEntry("Cream",                         c1,   227),
            IngredientWeightEntry("Cream Cheese",                  c1,   227),
            IngredientWeightEntry("Cream of Coconut",              c12,  142),
            IngredientWeightEntry("Crème Fraîche",                 c12,  113),
            IngredientWeightEntry("Currants",                      c1,   142),

            // D
            IngredientWeightEntry("Dates (chopped)",               c1,   149),
            IngredientWeightEntry("Demerara Sugar",                c1,   220),
            IngredientWeightEntry("Dried Milk (nonfat, powdered)", c14,   28),
            IngredientWeightEntry("Dried Potato Flakes",           c12,   43),
            IngredientWeightEntry("Durum Flour",                   c1,   124),

            // E
            IngredientWeightEntry("Espresso Powder",               tb1,    7),

            // F
            IngredientWeightEntry("Figs (dried, chopped)",         c1,   149),
            IngredientWeightEntry("Flax Meal",                     c12,   50),
            IngredientWeightEntry("Flaxseed",                      c14,   35),

            // G
            IngredientWeightEntry("Ghee",                          c14,   44),
            IngredientWeightEntry("Ginger (fresh, sliced)",        c14,   57),
            IngredientWeightEntry("Gluten-Free All-Purpose Flour", c1,   156),
            IngredientWeightEntry("Gluten-Free Bread Flour",       c1,   120),
            IngredientWeightEntry("Gluten-Free Pizza Flour",       c1,   100),
            IngredientWeightEntry("Glutinous Rice Flour",          c1,   120),
            IngredientWeightEntry("Graham Cracker Crumbs",         c1,   100),
            IngredientWeightEntry("Granola",                       c1,   113),
            IngredientWeightEntry("Guava Paste",                   c14,  100),

            // H
            IngredientWeightEntry("Harvest Grains Blend",          c12,   74),
            IngredientWeightEntry("Hazelnut Flour",                c1,    89),
            IngredientWeightEntry("Hazelnut Praline Paste",        c12,  156),
            IngredientWeightEntry("Hazelnut Spread",               c12,  160),
            IngredientWeightEntry("Hazelnuts (whole)",             c1,   142),
            IngredientWeightEntry("Honey",                         tb1,   21),

            // J
            IngredientWeightEntry("Jam or Preserves",              c14,   85),

            // K
            IngredientWeightEntry("Key Lime Juice",                c1,   227),

            // L
            IngredientWeightEntry("Lard",                          c12,  113),
            IngredientWeightEntry("Leeks (diced)",                 c1,    92),
            IngredientWeightEntry("Lemon Curd",                    c12,  113),
            IngredientWeightEntry("Lemon Juice",                   tb1,   14),

            // M
            IngredientWeightEntry("Macadamia Nuts",                c1,   149),
            IngredientWeightEntry("Malt Syrup",                    tb2,   43),
            IngredientWeightEntry("Maple Sugar",                   c12,   78),
            IngredientWeightEntry("Maple Syrup",                   c12,  156),
            IngredientWeightEntry("Marshmallow Fluff",             c1,   128),
            IngredientWeightEntry("Marshmallows (mini)",           c1,    43),
            IngredientWeightEntry("Masa Harina",                   c1,    93),
            IngredientWeightEntry("Mascarpone Cheese",             c1,   227),
            IngredientWeightEntry("Mashed Potatoes",               c1,   213),
            IngredientWeightEntry("Mashed Sweet Potatoes",         c1,   240),
            IngredientWeightEntry("Mayonnaise",                    c12,  113),
            IngredientWeightEntry("Medium Rye Flour",              c1,   106),
            IngredientWeightEntry("Meringue Powder",               c14,   43),
            IngredientWeightEntry("Milk (evaporated)",             c12,  113),
            IngredientWeightEntry("Milk (fresh)",                  c1,   227),
            IngredientWeightEntry("Millet (whole)",                c12,  103),
            IngredientWeightEntry("Mini Chocolate Chips",          c1,   177),
            IngredientWeightEntry("Molasses",                      c14,   85),
            IngredientWeightEntry("Mushrooms (sliced)",            c1,    78),

            // N
            IngredientWeightEntry("Nutella",                       c12,  149),

            // O
            IngredientWeightEntry("Oat Bran",                      c12,   53),
            IngredientWeightEntry("Oat Flour",                     c1,    92),
            IngredientWeightEntry("Oats (old-fashioned)",          c1,    89),
            IngredientWeightEntry("Oats (rolled)",                 c1,   113),
            IngredientWeightEntry("Olive Oil",                     c14,   50),
            IngredientWeightEntry("Olives (sliced)",               c1,   142),
            IngredientWeightEntry("Onions (fresh, diced)",         c1,   142),

            // P
            IngredientWeightEntry("Palm Shortening",               c14,   45),
            IngredientWeightEntry("Passion Fruit Purée",           c13,   60),
            IngredientWeightEntry("Pasta Flour Blend",             c1,   145),
            IngredientWeightEntry("Pastry Flour",                  c1,   106),
            IngredientWeightEntry("Peaches (diced)",               c1,   170),
            IngredientWeightEntry("Peanut Butter",                 c12,  135),
            IngredientWeightEntry("Peanuts (whole)",               c1,   142),
            IngredientWeightEntry("Pears (diced)",                 c1,   163),
            IngredientWeightEntry("Pecan Meal",                    c1,    80),
            IngredientWeightEntry("Pecans (diced)",                c12,   57),
            IngredientWeightEntry("Pecans (whole)",                c1,   105),
            IngredientWeightEntry("Pine Nuts",                     c12,   71),
            IngredientWeightEntry("Pineapple (crushed, drained)",  c1,   256),
            IngredientWeightEntry("Pineapple (dried)",             c12,   71),
            IngredientWeightEntry("Pineapple (fresh or canned)",   c1,   170),
            IngredientWeightEntry("Pistachio Nuts (shelled)",      c12,   60),
            IngredientWeightEntry("Pistachio Paste",               c14,   78),
            IngredientWeightEntry("Pizza Sauce",                   c14,   57),
            IngredientWeightEntry("Polenta",                       c1,   163),
            IngredientWeightEntry("Poppy Seeds",                   tb2,   18),
            IngredientWeightEntry("Potato Flour",                  c14,   46),
            IngredientWeightEntry("Potato Starch",                 c1,   152),
            IngredientWeightEntry("Pumpernickel Flour",            c1,   106),
            IngredientWeightEntry("Pumpkin Purée",                 c1,   227),
            IngredientWeightEntry("Pumpkin Seeds",                 c14,   40),

            // Q
            IngredientWeightEntry("Quinoa (cooked)",               c1,   184),
            IngredientWeightEntry("Quinoa (whole)",                c1,   177),
            IngredientWeightEntry("Quinoa Flour",                  c1,   110),

            // R
            IngredientWeightEntry("Raisins (loose)",               c1,   149),
            IngredientWeightEntry("Raisins (packed)",              c12,   85),
            IngredientWeightEntry("Raspberries (fresh)",           c1,   120),
            IngredientWeightEntry("Rice (long grain, dry)",        c12,   99),
            IngredientWeightEntry("Rice Flour (white)",            c1,   142),
            IngredientWeightEntry("Rye Flakes",                    c1,   124),
            IngredientWeightEntry("Rye Flour",                     c1,   106),

            // S
            IngredientWeightEntry("Salt (table)",                  tb1,   18),
            IngredientWeightEntry("Salt (Kosher, Diamond Crystal)",tb1,    8),
            IngredientWeightEntry("Salt (Kosher, Morton's)",       tb1,   16),
            IngredientWeightEntry("Scallions (sliced)",            c1,    64),
            IngredientWeightEntry("Self-Rising Flour",             c1,   113),
            IngredientWeightEntry("Semolina Flour",                c1,   163),
            IngredientWeightEntry("Sesame Seeds",                  c12,   71),
            IngredientWeightEntry("Shallots (sliced)",             c1,   156),
            IngredientWeightEntry("Sorghum Flour",                 c1,   138),
            IngredientWeightEntry("Sour Cream",                    c1,   227),
            IngredientWeightEntry("Sourdough Starter",             c1,   234),
            IngredientWeightEntry("Soy Flour",                     c14,   35),
            IngredientWeightEntry("Spelt Flour",                   c1,    99),
            IngredientWeightEntry("Steel Cut Oats",                c12,   70),
            IngredientWeightEntry("Strawberries (fresh sliced)",   c1,   167),
            IngredientWeightEntry("Sugar (granulated white)",      c1,   198),
            IngredientWeightEntry("Sunflower Seeds",               c14,   35),

            // T
            IngredientWeightEntry("Tahini Paste",                  c12,  128),
            IngredientWeightEntry("Tapioca Starch",                c1,   113),
            IngredientWeightEntry("Teff Flour",                    c1,   135),

            // V
            IngredientWeightEntry("Vanilla Extract",               tb1,   14),
            IngredientWeightEntry("Vegetable Oil",                 c1,   198),
            IngredientWeightEntry("Vegetable Shortening",          c14,   46),

            // W
            IngredientWeightEntry("Walnuts (chopped)",             c1,   113),
            IngredientWeightEntry("Walnuts (whole)",               c12,   64),
            IngredientWeightEntry("Water",                         c1,   227),
            IngredientWeightEntry("Wheat Bran",                    c12,   32),
            IngredientWeightEntry("Wheat Germ",                    c14,   28),
            IngredientWeightEntry("White Chocolate Chips",         c1,   170),
            IngredientWeightEntry("White Rye Flour",               c1,   106),
            IngredientWeightEntry("Whole Wheat Flour",             c1,   113),
            IngredientWeightEntry("Whole Wheat Pastry Flour",      c1,    96),

            // Y
            IngredientWeightEntry("Yeast (instant)",               ts2,    6),
            IngredientWeightEntry("Yogurt",                        c1,   227),

            // Z
            IngredientWeightEntry("Zucchini (shredded)",           c1,   135),
        ]
    }()

    static func suggestions(for query: String) -> [IngredientWeightEntry] {
        let q = query.lowercased().trimmingCharacters(in: .whitespaces)
        guard q.count >= 2 else { return [] }
        return entries.filter { $0.name.lowercased().contains(q) }
    }
}
