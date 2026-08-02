//
//  PlantCatalog.swift
//  Focus Forest Adventure
//
//  Every growing thing in the magic forest, in one place. Each species
//  carries a kid-friendly fact (spoken when the child taps it) plus the
//  handful of numbers the 3D builder needs to grow it procedurally:
//  a form archetype, a height, and two colors.
//
//  Pure domain — no SwiftUI, no SceneKit, no UIKit. The renderer maps
//  `PlantForm` to geometry; adding a species here makes it appear in the
//  forest and become tappable with no renderer changes at all.
//

import Foundation

// MARK: - Color

/// A plain RGB triple so the catalog stays free of UIKit/SwiftUI.
struct PlantColor: Hashable, Sendable {
    let r: Double, g: Double, b: Double
    init(_ r: Double, _ g: Double, _ b: Double) { self.r = r; self.g = g; self.b = b }
}

extension PlantColor {
    static let leaf      = PlantColor(0.29, 0.55, 0.30)
    static let deepLeaf  = PlantColor(0.16, 0.40, 0.22)
    static let paleLeaf  = PlantColor(0.55, 0.75, 0.45)
    static let blueLeaf  = PlantColor(0.38, 0.58, 0.48)
    static let olive     = PlantColor(0.48, 0.52, 0.26)
    static let grey      = PlantColor(0.62, 0.68, 0.58)
    static let straw     = PlantColor(0.82, 0.76, 0.45)
    static let white     = PlantColor(0.98, 0.97, 0.94)
    static let cream     = PlantColor(0.98, 0.94, 0.78)
    static let gold      = PlantColor(1.00, 0.80, 0.25)
    static let yellow    = PlantColor(0.98, 0.88, 0.35)
    static let orange    = PlantColor(0.97, 0.58, 0.20)
    static let tangerine = PlantColor(0.99, 0.68, 0.25)
    static let red       = PlantColor(0.88, 0.24, 0.22)
    static let crimson   = PlantColor(0.74, 0.13, 0.24)
    static let cherryRed = PlantColor(0.85, 0.16, 0.30)
    static let pink      = PlantColor(0.97, 0.62, 0.72)
    static let hotPink   = PlantColor(0.93, 0.35, 0.58)
    static let blush     = PlantColor(0.99, 0.83, 0.86)
    static let purple    = PlantColor(0.55, 0.35, 0.72)
    static let violet    = PlantColor(0.66, 0.48, 0.86)
    static let plum      = PlantColor(0.36, 0.18, 0.38)
    static let indigo    = PlantColor(0.28, 0.30, 0.62)
    static let blue      = PlantColor(0.36, 0.54, 0.86)
    static let sky       = PlantColor(0.62, 0.80, 0.94)
    static let teal      = PlantColor(0.20, 0.60, 0.58)
    static let brown     = PlantColor(0.48, 0.34, 0.22)
    static let tan       = PlantColor(0.76, 0.62, 0.42)
    static let bark      = PlantColor(0.42, 0.30, 0.20)
    static let lime      = PlantColor(0.66, 0.84, 0.30)
    static let mint      = PlantColor(0.62, 0.88, 0.72)
    static let peach     = PlantColor(0.99, 0.74, 0.55)
    static let coral     = PlantColor(0.98, 0.52, 0.45)
    static let magenta   = PlantColor(0.82, 0.28, 0.60)
    static let ivory     = PlantColor(0.95, 0.92, 0.82)
}

// MARK: - Form

/// How the renderer grows a species. Fourteen archetypes cover every
/// plant in the catalog; the species' height and colors do the rest.
enum PlantForm: String, Hashable, Sendable, CaseIterable {
    case tuft          // grass blades fanning from the ground
    case cane          // tall segmented stalks (bamboo, corn)
    case reed          // slim stalks topped with a head (cattail)
    case bloom         // single stem, one round flower head
    case spike         // several stems with capsule flower spires
    case bush          // rounded leafy shrub
    case berryBush     // leafy shrub studded with fruit
    case fruitTree     // small trunk, canopy, hanging fruit
    case mushroom      // stalk and cap
    case groundCover   // low spreading mat
    case vine          // climbing stem with leaves
    case succulent     // thick fleshy pads
    case palm          // bare trunk with arching fronds
    case rootVeg       // leafy top over a peeking root
}

// MARK: - Species

struct ForestPlant: Hashable, Sendable, Identifiable {
    let key: String
    let name: String
    let emoji: String
    let fact: String
    let form: PlantForm
    /// Approximate world height in metres (the child's eye is at 1.75).
    let height: Float
    /// Flower / fruit / accent color.
    let accent: PlantColor
    /// Foliage color.
    let foliage: PlantColor

    var id: String { key }
}

// MARK: - Catalog

enum PlantCatalog {

    private static func p(
        _ key: String, _ name: String, _ emoji: String,
        _ form: PlantForm, _ height: Float,
        _ accent: PlantColor, _ foliage: PlantColor = .leaf,
        _ fact: String
    ) -> ForestPlant {
        ForestPlant(key: key, name: name, emoji: emoji, fact: fact,
                    form: form, height: height, accent: accent, foliage: foliage)
    }

    /// Every species that can grow in the forest. Order is not meaningful —
    /// the scatterer walks the list so new entries appear automatically.
    static let all: [ForestPlant] = [

        // MARK: Grasses, canes and reeds

        p("lemongrass", String(localized: "Lemongrass"), "🌾", .tuft, 1.2, .lime, .paleLeaf,
          String(localized: "Rub a lemongrass leaf and your fingers smell like lemons!")),
        p("tallgrass", String(localized: "Tall Grass"), "🌾", .tuft, 1.0, .straw, .leaf,
          String(localized: "Tall grass is a cozy hiding home for rabbits and crickets.")),
        p("wheat", String(localized: "Wheat"), "🌾", .reed, 1.1, .straw, .olive,
          String(localized: "Wheat seeds are ground into flour to make bread.")),
        p("barley", String(localized: "Barley"), "🌾", .reed, 1.0, .straw, .olive,
          String(localized: "Barley has long whiskers on top called awns.")),
        p("oats", String(localized: "Oats"), "🌾", .reed, 0.9, .cream, .olive,
          String(localized: "Oats become the porridge some people eat for breakfast.")),
        p("rice", String(localized: "Rice"), "🌾", .reed, 0.8, .straw, .paleLeaf,
          String(localized: "Rice grows with its feet in shallow water.")),
        p("bamboo", String(localized: "Bamboo"), "🎋", .cane, 4.5, .lime, .deepLeaf,
          String(localized: "Bamboo is the fastest growing plant on Earth.")),
        p("sugarcane", String(localized: "Sugarcane"), "🎍", .cane, 3.2, .lime, .paleLeaf,
          String(localized: "The sugar in your cake may have come from sugarcane juice.")),
        p("corn", String(localized: "Corn"), "🌽", .cane, 2.2, .gold, .paleLeaf,
          String(localized: "Every corn cob has silky threads — one for every single kernel.")),
        p("cattail", String(localized: "Cattail"), "🌿", .reed, 1.6, .brown, .deepLeaf,
          String(localized: "A cattail's brown top is packed with thousands of fluffy seeds.")),
        p("papyrus", String(localized: "Papyrus"), "🌿", .reed, 2.4, .lime, .leaf,
          String(localized: "Long ago people made the first paper from papyrus reeds.")),
        p("pampas", String(localized: "Pampas Grass"), "🌾", .tuft, 1.8, .ivory, .paleLeaf,
          String(localized: "Pampas grass has feathery plumes that wave like flags.")),
        p("fountaingrass", String(localized: "Fountain Grass"), "🌾", .tuft, 0.9, .blush, .olive,
          String(localized: "Fountain grass arches over like water splashing from a fountain.")),
        p("ryegrass", String(localized: "Rye Grass"), "🌾", .tuft, 0.6, .lime, .leaf,
          String(localized: "Rye grass is the soft green that makes playing fields springy.")),

        // MARK: Berries

        p("mulberry", String(localized: "Mulberry"), "🫐", .berryBush, 1.6, .plum, .deepLeaf,
          String(localized: "Mulberries stain your fingers purple — and silkworms eat the leaves!")),
        p("blueberry", String(localized: "Blueberry"), "🫐", .berryBush, 0.9, .indigo, .blueLeaf,
          String(localized: "Blueberries start out green and slowly turn deep blue.")),
        p("raspberry", String(localized: "Raspberry"), "🍇", .berryBush, 1.1, .cherryRed, .leaf,
          String(localized: "A raspberry is really a bundle of tiny juicy balls stuck together.")),
        p("blackberry", String(localized: "Blackberry"), "🫐", .berryBush, 1.2, .plum, .deepLeaf,
          String(localized: "Blackberry stems have little thorns, so pick them carefully.")),
        p("strawberry", String(localized: "Strawberry"), "🍓", .groundCover, 0.3, .red, .leaf,
          String(localized: "Strawberries wear their seeds on the outside — count the tiny dots!")),
        p("gooseberry", String(localized: "Gooseberry"), "🫐", .berryBush, 1.0, .lime, .leaf,
          String(localized: "Gooseberries are stripy and sour enough to make you squeak.")),
        p("cranberry", String(localized: "Cranberry"), "🫐", .groundCover, 0.25, .crimson, .deepLeaf,
          String(localized: "Cranberries bounce when they are ripe — that's how farmers test them.")),
        p("elderberry", String(localized: "Elderberry"), "🫐", .berryBush, 1.8, .plum, .leaf,
          String(localized: "Elderflowers turn into hundreds of tiny dark elderberries.")),
        p("currant", String(localized: "Currant"), "🫐", .berryBush, 1.0, .red, .leaf,
          String(localized: "Currants hang in little strings like tiny shiny beads.")),
        p("berry", String(localized: "Berry Bush"), "🫐", .berryBush, 1.0, .indigo, .leaf,
          String(localized: "Birds eat berries and spread the seeds so new bushes can grow.")),

        // MARK: Fruit trees

        p("cherry", String(localized: "Cherry Tree"), "🍒", .fruitTree, 3.4, .cherryRed, .deepLeaf,
          String(localized: "In spring a cherry tree is covered in pink blossom before any fruit.")),
        p("apple", String(localized: "Apple Tree"), "🍎", .fruitTree, 3.6, .red, .leaf,
          String(localized: "Apples float, because a fifth of an apple is just air.")),
        p("pear", String(localized: "Pear Tree"), "🍐", .fruitTree, 3.4, .lime, .leaf,
          String(localized: "Pears ripen best after they are picked, not on the tree.")),
        p("peach", String(localized: "Peach Tree"), "🍑", .fruitTree, 3.0, .peach, .leaf,
          String(localized: "A peach wears a fuzzy coat to protect its soft skin.")),
        p("plum", String(localized: "Plum Tree"), "🍑", .fruitTree, 3.0, .plum, .deepLeaf,
          String(localized: "When a plum dries in the sun it becomes a wrinkly prune.")),
        p("apricot", String(localized: "Apricot Tree"), "🍑", .fruitTree, 2.9, .tangerine, .leaf,
          String(localized: "Apricots are golden little cousins of the peach.")),
        p("fig", String(localized: "Fig Tree"), "🫒", .fruitTree, 3.2, .plum, .deepLeaf,
          String(localized: "A fig's flowers grow hidden inside the fruit!")),
        p("mango", String(localized: "Mango Tree"), "🥭", .fruitTree, 4.2, .tangerine, .deepLeaf,
          String(localized: "Mango trees can keep making sweet fruit for a hundred years.")),
        p("guava", String(localized: "Guava Tree"), "🍈", .fruitTree, 2.8, .lime, .leaf,
          String(localized: "One guava has more vitamin C than an orange.")),
        p("lemon", String(localized: "Lemon Tree"), "🍋", .fruitTree, 2.6, .yellow, .deepLeaf,
          String(localized: "Lemon trees can hold flowers and fruit at the very same time.")),
        p("orange", String(localized: "Orange Tree"), "🍊", .fruitTree, 3.0, .orange, .deepLeaf,
          String(localized: "Orange blossom smells so sweet that bees travel far to find it.")),
        p("lime", String(localized: "Lime Tree"), "🍋", .fruitTree, 2.4, .lime, .deepLeaf,
          String(localized: "Limes are picked while still green and extra sour.")),
        p("pomegranate", String(localized: "Pomegranate"), "🍎", .fruitTree, 2.6, .crimson, .leaf,
          String(localized: "Crack open a pomegranate and hundreds of ruby seeds spill out.")),
        p("olive", String(localized: "Olive Tree"), "🫒", .fruitTree, 3.0, .olive, .grey,
          String(localized: "Some olive trees are older than a thousand years.")),
        p("almond", String(localized: "Almond Tree"), "🌰", .fruitTree, 3.2, .tan, .paleLeaf,
          String(localized: "An almond is the seed hiding inside a fuzzy green fruit.")),
        p("walnut", String(localized: "Walnut Tree"), "🌰", .fruitTree, 4.0, .brown, .deepLeaf,
          String(localized: "A walnut shell is so tough that squirrels need both paws.")),
        p("chestnut", String(localized: "Chestnut Tree"), "🌰", .fruitTree, 4.2, .brown, .leaf,
          String(localized: "Chestnuts wear a spiky green jacket until they are ripe.")),
        p("banana", String(localized: "Banana Plant"), "🍌", .palm, 3.0, .yellow, .paleLeaf,
          String(localized: "A banana plant is not a tree — it is the world's biggest herb!")),
        p("papaya", String(localized: "Papaya"), "🍈", .palm, 3.2, .tangerine, .leaf,
          String(localized: "Papayas grow in a bunch hugging the very top of the trunk.")),
        p("coconut", String(localized: "Coconut Palm"), "🥥", .palm, 5.0, .brown, .deepLeaf,
          String(localized: "Coconuts can float across the sea and sprout on a new beach.")),
        p("date", String(localized: "Date Palm"), "🌴", .palm, 4.6, .tan, .olive,
          String(localized: "Date palms love the desert and drink from deep underground.")),
        p("avocado", String(localized: "Avocado Tree"), "🥑", .fruitTree, 3.8, .deepLeaf, .deepLeaf,
          String(localized: "An avocado has one giant seed right in the middle.")),

        // MARK: Flowers

        p("sunflower", String(localized: "Sunflower"), "🌻", .bloom, 1.8, .gold, .leaf,
          String(localized: "Sunflowers turn their faces to follow the sun across the sky!")),
        p("tulip", String(localized: "Tulip"), "🌷", .bloom, 0.6, .hotPink, .paleLeaf,
          String(localized: "Tulips close their petals at night to keep warm.")),
        p("daisy", String(localized: "Daisy"), "🌼", .bloom, 0.4, .white, .leaf,
          String(localized: "A daisy is really many tiny flowers packed together in one!")),
        p("rose", String(localized: "Rose"), "🌹", .bush, 1.0, .crimson, .deepLeaf,
          String(localized: "A rose's thorns are really tiny prickles that help it climb.")),
        p("marigold", String(localized: "Marigold"), "🌼", .bloom, 0.5, .orange, .leaf,
          String(localized: "Marigolds smell strong enough to keep hungry bugs away.")),
        p("jasmine", String(localized: "Jasmine"), "🌸", .vine, 1.4, .white, .deepLeaf,
          String(localized: "Jasmine saves its sweetest smell for the night time.")),
        p("hibiscus", String(localized: "Hibiscus"), "🌺", .bush, 1.6, .red, .deepLeaf,
          String(localized: "A hibiscus flower opens for just one day, then a new one comes.")),
        p("lotus", String(localized: "Lotus"), "🪷", .bloom, 0.5, .blush, .paleLeaf,
          String(localized: "Lotus leaves are so slippery that mud slides right off them.")),
        p("lily", String(localized: "Lily"), "🌸", .bloom, 0.9, .white, .deepLeaf,
          String(localized: "Lilies have six petals and dusty orange pollen inside.")),
        p("orchid", String(localized: "Orchid"), "🌸", .spike, 0.6, .magenta, .deepLeaf,
          String(localized: "Some orchids grow high up on tree branches instead of in soil.")),
        p("poppy", String(localized: "Poppy"), "🌺", .bloom, 0.6, .red, .paleLeaf,
          String(localized: "A poppy's petals are as thin and crinkly as tissue paper.")),
        p("iris", String(localized: "Iris"), "🌸", .bloom, 0.8, .violet, .paleLeaf,
          String(localized: "The iris is named after the rainbow, because it comes in every color.")),
        p("dahlia", String(localized: "Dahlia"), "🌸", .bloom, 0.9, .magenta, .leaf,
          String(localized: "A dahlia can have hundreds of petals in one single flower.")),
        p("zinnia", String(localized: "Zinnia"), "🌼", .bloom, 0.6, .coral, .leaf,
          String(localized: "Zinnias grow so easily that they are perfect for a first garden.")),
        p("peony", String(localized: "Peony"), "🌸", .bush, 0.8, .blush, .deepLeaf,
          String(localized: "Ants love peony buds and help them open.")),
        p("bluebell", String(localized: "Bluebell"), "🔔", .spike, 0.4, .indigo, .leaf,
          String(localized: "Bluebells carpet whole woods in blue every springtime.")),
        p("snowdrop", String(localized: "Snowdrop"), "🤍", .bloom, 0.25, .white, .paleLeaf,
          String(localized: "Snowdrops are brave — they push up through the snow.")),
        p("foxglove", String(localized: "Foxglove"), "🌸", .spike, 1.2, .hotPink, .deepLeaf,
          String(localized: "Each foxglove flower is a little bell that bumblebees crawl inside.")),
        p("primrose", String(localized: "Primrose"), "🌼", .groundCover, 0.25, .cream, .leaf,
          String(localized: "Primrose means 'first rose' because it blooms so early.")),
        p("violet", String(localized: "Violet"), "💜", .groundCover, 0.2, .violet, .leaf,
          String(localized: "Sweet violets hide low down and smell like candy.")),
        p("buttercup", String(localized: "Buttercup"), "🌼", .bloom, 0.3, .yellow, .leaf,
          String(localized: "Buttercup petals are so shiny they reflect gold onto your chin.")),
        p("clover", String(localized: "Clover"), "🍀", .groundCover, 0.18, .white, .leaf,
          String(localized: "Most clovers have three leaves — finding four means good luck!")),
        p("dandelion", String(localized: "Dandelion"), "🌼", .bloom, 0.35, .gold, .leaf,
          String(localized: "Blow a dandelion clock and every seed flies away on a parachute.")),
        p("lavender", String(localized: "Lavender"), "💜", .spike, 0.8, .violet, .grey,
          String(localized: "Lavender smells so nice that bees and butterflies love it.")),
        p("cornflower", String(localized: "Cornflower"), "💙", .bloom, 0.6, .blue, .grey,
          String(localized: "Cornflowers are such a bright blue that a color is named after them.")),
        p("sweetpea", String(localized: "Sweet Pea"), "🌸", .vine, 1.2, .pink, .paleLeaf,
          String(localized: "Sweet peas climb by curling springy tendrils around anything nearby.")),
        p("morningglory", String(localized: "Morning Glory"), "💜", .vine, 1.5, .purple, .leaf,
          String(localized: "Morning glory flowers open at sunrise and close by lunchtime.")),
        p("honeysuckle", String(localized: "Honeysuckle"), "🌼", .vine, 1.6, .cream, .deepLeaf,
          String(localized: "Honeysuckle holds a drop of nectar as sweet as honey.")),
        p("passionflower", String(localized: "Passion Flower"), "🌸", .vine, 1.5, .violet, .deepLeaf,
          String(localized: "A passion flower looks like a tiny purple clock face.")),
        p("chamomile", String(localized: "Chamomile"), "🌼", .bloom, 0.35, .white, .paleLeaf,
          String(localized: "Chamomile flowers smell like apples and make a calming tea.")),
        p("nasturtium", String(localized: "Nasturtium"), "🌺", .groundCover, 0.3, .orange, .paleLeaf,
          String(localized: "Nasturtium leaves are round like little lily pads, and you can eat them.")),
        p("hydrangea", String(localized: "Hydrangea"), "💠", .bush, 1.4, .sky, .leaf,
          String(localized: "Hydrangeas change color depending on the soil they drink from.")),
        p("azalea", String(localized: "Azalea"), "🌸", .bush, 1.2, .magenta, .deepLeaf,
          String(localized: "An azalea bush can disappear completely under its own flowers.")),
        p("rhododendron", String(localized: "Rhododendron"), "🌺", .bush, 2.0, .hotPink, .deepLeaf,
          String(localized: "Rhododendron leaves curl up tight when the air turns cold.")),
        p("magnolia", String(localized: "Magnolia"), "🌸", .fruitTree, 3.4, .blush, .deepLeaf,
          String(localized: "Magnolias are so old that beetles pollinated them before bees existed.")),
        p("wisteria", String(localized: "Wisteria"), "💜", .vine, 2.2, .lavenderPurple, .leaf,
          String(localized: "Wisteria hangs down in long purple waterfalls of flowers.")),

        // MARK: Herbs

        p("mint", String(localized: "Mint"), "🌿", .bush, 0.5, .paleLeaf, .leaf,
          String(localized: "Crush a mint leaf and your mouth feels cool just from the smell.")),
        p("basil", String(localized: "Basil"), "🌿", .bush, 0.45, .lime, .leaf,
          String(localized: "Basil leaves love warm sunshine and hate the cold.")),
        p("rosemary", String(localized: "Rosemary"), "🌿", .spike, 0.8, .sky, .blueLeaf,
          String(localized: "Rosemary has needle leaves, a bit like a tiny pine tree.")),
        p("thyme", String(localized: "Thyme"), "🌿", .groundCover, 0.2, .violet, .grey,
          String(localized: "Thyme grows into a soft cushion you could almost sit on.")),
        p("sage", String(localized: "Sage"), "🌿", .bush, 0.6, .violet, .grey,
          String(localized: "Sage leaves feel velvety and soft, like a bunny's ear.")),
        p("oregano", String(localized: "Oregano"), "🌿", .bush, 0.4, .blush, .leaf,
          String(localized: "Oregano is the herb that makes pizza smell like pizza.")),
        p("parsley", String(localized: "Parsley"), "🌿", .tuft, 0.35, .lime, .deepLeaf,
          String(localized: "Parsley leaves are curly and frilly like green lace.")),
        p("coriander", String(localized: "Coriander"), "🌿", .tuft, 0.4, .white, .paleLeaf,
          String(localized: "Coriander gives you leaves to eat AND seeds to sprinkle.")),
        p("dill", String(localized: "Dill"), "🌿", .reed, 0.9, .yellow, .blueLeaf,
          String(localized: "Dill leaves are so thin and feathery they look like green hair.")),
        p("fennel", String(localized: "Fennel"), "🌿", .reed, 1.4, .gold, .blueLeaf,
          String(localized: "Fennel tastes a little like liquorice sweets.")),
        p("lemonbalm", String(localized: "Lemon Balm"), "🌿", .bush, 0.5, .paleLeaf, .lime,
          String(localized: "Lemon balm leaves smell like lemon sherbet when you rub them.")),
        p("aloe", String(localized: "Aloe Vera"), "🌵", .succulent, 0.6, .paleLeaf, .mint,
          String(localized: "Aloe leaves are full of cool jelly that soothes sore skin.")),

        // MARK: Ferns, moss and small green things

        p("fern", String(localized: "Fern"), "🌿", .tuft, 1.1, .deepLeaf, .leaf,
          String(localized: "Ferns are older than dinosaurs — they have no flowers at all!")),
        p("bracken", String(localized: "Bracken"), "🌿", .tuft, 1.3, .olive, .deepLeaf,
          String(localized: "Bracken unrolls from a curly tip called a fiddlehead.")),
        p("maidenhair", String(localized: "Maidenhair Fern"), "🌿", .tuft, 0.5, .lime, .paleLeaf,
          String(localized: "Maidenhair fern has black stems as thin as thread.")),
        p("moss", String(localized: "Moss"), "🌿", .groundCover, 0.1, .lime, .deepLeaf,
          String(localized: "Moss has no roots — it drinks rain straight through its leaves.")),
        p("lichen", String(localized: "Lichen"), "🌿", .groundCover, 0.08, .mint, .grey,
          String(localized: "Lichen is two living things — a fungus and an algae — sharing one home.")),
        p("clubmoss", String(localized: "Club Moss"), "🌿", .groundCover, 0.2, .deepLeaf, .leaf,
          String(localized: "Club moss looks like a forest for beetles, only a few centimetres tall.")),
        p("horsetail", String(localized: "Horsetail"), "🌿", .reed, 0.7, .olive, .deepLeaf,
          String(localized: "Horsetail stems are ribbed and gritty, like tiny green bottle brushes.")),
        p("ivy", String(localized: "Ivy"), "🍃", .vine, 1.8, .deepLeaf, .deepLeaf,
          String(localized: "Ivy climbs walls using thousands of tiny sticky roots.")),
        p("grapevine", String(localized: "Grape Vine"), "🍇", .vine, 1.9, .plum, .leaf,
          String(localized: "Grapes grow in bunches and dry into raisins in the sun.")),

        // MARK: Mushrooms

        p("mushroom", String(localized: "Mushroom"), "🍄", .mushroom, 0.5, .red, .cream,
          String(localized: "Mushrooms are not plants — they are fungi, and they turn old leaves into soil.")),
        p("toadstool", String(localized: "Toadstool"), "🍄", .mushroom, 0.55, .crimson, .white,
          String(localized: "Spotty red toadstools look magical, but they are only for looking at.")),
        p("chanterelle", String(localized: "Chanterelle"), "🍄", .mushroom, 0.35, .gold, .cream,
          String(localized: "Chanterelles are shaped like tiny golden trumpets.")),
        p("morel", String(localized: "Morel"), "🍄", .mushroom, 0.4, .brown, .tan,
          String(localized: "A morel's cap is wrinkled all over like a little honeycomb.")),
        p("puffball", String(localized: "Puffball"), "🍄", .mushroom, 0.3, .ivory, .cream,
          String(localized: "Tap a ripe puffball and it puffs out a cloud of dusty spores.")),
        p("oystermushroom", String(localized: "Oyster Mushroom"), "🍄", .mushroom, 0.3, .grey, .ivory,
          String(localized: "Oyster mushrooms grow in shelves along fallen logs.")),
        p("inkcap", String(localized: "Ink Cap"), "🍄", .mushroom, 0.35, .grey, .white,
          String(localized: "When an ink cap gets old it melts into black ink.")),

        // MARK: Vegetables

        p("carrot", String(localized: "Carrot"), "🥕", .rootVeg, 0.4, .orange, .paleLeaf,
          String(localized: "The part of a carrot you eat is really its root.")),
        p("beet", String(localized: "Beetroot"), "🌱", .rootVeg, 0.35, .crimson, .leaf,
          String(localized: "Beetroot juice is so purple it can dye your dinner pink.")),
        p("radish", String(localized: "Radish"), "🌱", .rootVeg, 0.3, .hotPink, .leaf,
          String(localized: "Radishes grow so fast you can pick them a month after planting.")),
        p("turnip", String(localized: "Turnip"), "🌱", .rootVeg, 0.35, .violet, .leaf,
          String(localized: "Turnips keep growing happily even when the weather turns cold.")),
        p("potato", String(localized: "Potato"), "🥔", .rootVeg, 0.45, .tan, .deepLeaf,
          String(localized: "Potatoes grow underground on the plant's stems, not its roots.")),
        p("onion", String(localized: "Onion"), "🧅", .rootVeg, 0.4, .ivory, .paleLeaf,
          String(localized: "An onion is made of layers, like a little round parcel.")),
        p("garlic", String(localized: "Garlic"), "🧄", .rootVeg, 0.4, .white, .paleLeaf,
          String(localized: "One garlic bulb splits into many little cloves.")),
        p("pumpkin", String(localized: "Pumpkin"), "🎃", .groundCover, 0.5, .orange, .deepLeaf,
          String(localized: "A pumpkin can grow bigger than the child who planted it.")),
        p("tomato", String(localized: "Tomato"), "🍅", .bush, 1.0, .red, .leaf,
          String(localized: "A tomato is really a fruit, even though we eat it with dinner.")),
        p("pea", String(localized: "Pea"), "🫛", .vine, 1.1, .lime, .paleLeaf,
          String(localized: "Peas hide in a pod like green beads in a pencil case.")),
        p("bean", String(localized: "Runner Bean"), "🫘", .vine, 1.8, .red, .leaf,
          String(localized: "Runner beans twist round their poles the same way every time.")),
        p("cabbage", String(localized: "Cabbage"), "🥬", .groundCover, 0.35, .paleLeaf, .blueLeaf,
          String(localized: "A cabbage is one giant bud made of hundreds of wrapped leaves.")),
        p("lettuce", String(localized: "Lettuce"), "🥬", .groundCover, 0.25, .lime, .paleLeaf,
          String(localized: "Lettuce is mostly water — that's why it's so crunchy.")),
        p("spinach", String(localized: "Spinach"), "🥬", .tuft, 0.3, .deepLeaf, .deepLeaf,
          String(localized: "Spinach leaves are packed with iron to help you grow strong.")),
        p("chili", String(localized: "Chilli"), "🌶️", .bush, 0.7, .red, .deepLeaf,
          String(localized: "Chillies grow hot to stop animals eating their seeds — but birds don't mind!")),
        p("cucumber", String(localized: "Cucumber"), "🥒", .vine, 1.0, .deepLeaf, .leaf,
          String(localized: "Cucumbers are nearly all water, which is why they taste so cool.")),
        p("sunchoke", String(localized: "Sunchoke"), "🌻", .reed, 2.0, .gold, .leaf,
          String(localized: "Sunchokes have sunflower faces on top and knobbly food underneath.")),

        // MARK: Trees and shrubs

        p("oak", String(localized: "Oak"), "🌳", .fruitTree, 5.0, .brown, .deepLeaf,
          String(localized: "One oak tree can drop ten thousand acorns in a single autumn.")),
        p("maple", String(localized: "Maple"), "🍁", .fruitTree, 4.6, .red, .leaf,
          String(localized: "Maple seeds spin like helicopter blades as they fall.")),
        p("birch", String(localized: "Birch"), "🌳", .fruitTree, 4.2, .ivory, .paleLeaf,
          String(localized: "Birch bark is papery white and peels off in curly strips.")),
        p("pine", String(localized: "Pine"), "🌲", .fruitTree, 5.4, .brown, .deepLeaf,
          String(localized: "Pine cones open their scales when the weather is dry.")),
        p("willow", String(localized: "Willow"), "🌳", .palm, 4.4, .paleLeaf, .paleLeaf,
          String(localized: "A weeping willow's branches hang down like long green hair.")),
        p("banyan", String(localized: "Banyan"), "🌳", .fruitTree, 5.2, .bark, .deepLeaf,
          String(localized: "A banyan drops roots from its branches until one tree becomes a forest.")),
        p("neem", String(localized: "Neem"), "🌳", .fruitTree, 4.4, .lime, .leaf,
          String(localized: "Neem leaves taste so bitter that insects leave the tree alone.")),
        p("peepal", String(localized: "Peepal"), "🌳", .fruitTree, 4.8, .lime, .deepLeaf,
          String(localized: "Peepal leaves have a long pointed tail so rain runs straight off.")),
        p("eucalyptus", String(localized: "Eucalyptus"), "🌿", .fruitTree, 4.8, .grey, .blueLeaf,
          String(localized: "Koalas eat eucalyptus leaves and sleep most of the day.")),
        p("holly", String(localized: "Holly"), "🌿", .bush, 1.8, .red, .deepLeaf,
          String(localized: "Holly leaves have prickly edges to keep hungry animals away.")),
        p("boxwood", String(localized: "Boxwood"), "🌿", .bush, 1.0, .deepLeaf, .deepLeaf,
          String(localized: "Boxwood is so neat and tidy that gardeners clip it into animal shapes.")),
        p("juniper", String(localized: "Juniper"), "🌲", .bush, 1.4, .sky, .blueLeaf,
          String(localized: "Juniper berries are really tiny blue cones.")),
        p("hazel", String(localized: "Hazel"), "🌰", .bush, 2.2, .tan, .leaf,
          String(localized: "Hazel dangles yellow catkins in late winter, before its leaves.")),
        p("hawthorn", String(localized: "Hawthorn"), "🌸", .bush, 2.4, .white, .deepLeaf,
          String(localized: "Hawthorn is white with blossom in May and red with berries in autumn.")),
        p("bougainvillea", String(localized: "Bougainvillea"), "🌺", .vine, 2.4, .magenta, .leaf,
          String(localized: "The bright papery parts of bougainvillea are leaves, not petals.")),

        // MARK: Succulents and desert plants

        p("cactus", String(localized: "Cactus"), "🌵", .succulent, 1.2, .yellow, .deepLeaf,
          String(localized: "A cactus stores water inside its fat stem for months without rain.")),
        p("agave", String(localized: "Agave"), "🌵", .succulent, 0.9, .cream, .blueLeaf,
          String(localized: "An agave may wait thirty years to flower just once.")),
        p("jade", String(localized: "Jade Plant"), "🌿", .succulent, 0.6, .blush, .leaf,
          String(localized: "Jade plant leaves are plump little cushions full of water.")),
        p("prickly", String(localized: "Prickly Pear"), "🌵", .succulent, 0.9, .magenta, .paleLeaf,
          String(localized: "Prickly pear pads are flat like ping-pong bats, and the fruit is sweet.")),
        p("sedum", String(localized: "Sedum"), "🌿", .groundCover, 0.2, .pink, .mint,
          String(localized: "Sedum spreads over dry rocks where almost nothing else will grow.")),

        // MARK: Water plants

        p("waterlily", String(localized: "Water Lily"), "🪷", .groundCover, 0.15, .white, .deepLeaf,
          String(localized: "A water lily's leaf is a raft strong enough for a frog.")),
        p("duckweed", String(localized: "Duckweed"), "🌿", .groundCover, 0.05, .lime, .lime,
          String(localized: "Duckweed is one of the smallest flowering plants in the world.")),
        p("watercress", String(localized: "Watercress"), "🌿", .groundCover, 0.2, .white, .deepLeaf,
          String(localized: "Watercress grows with its toes in cold running streams.")),
        p("reed", String(localized: "Reed"), "🌾", .reed, 1.8, .straw, .olive,
          String(localized: "Reeds clean the water they grow in, like a natural filter."))
    ]

    /// Fast lookup by key (`learn.<key>` node names use this).
    static let byKey: [String: ForestPlant] = Dictionary(
        all.map { ($0.key, $0) }, uniquingKeysWith: { first, _ in first }
    )

    static func plant(_ key: String) -> ForestPlant? { byKey[key] }

    /// Species that carpet the open ground — small enough to walk among.
    static let understory: [ForestPlant] = all.filter {
        switch $0.form {
        case .fruitTree, .palm, .cane: false
        default: true
        }
    }

    /// The big ones, scattered more sparsely so the world stays walkable.
    static let canopy: [ForestPlant] = all.filter {
        switch $0.form {
        case .fruitTree, .palm, .cane: true
        default: false
        }
    }
}

extension PlantColor {
    /// Wisteria's particular purple (kept out of the shared palette so the
    /// named colors stay generic).
    static let lavenderPurple = PlantColor(0.62, 0.52, 0.84)
}
