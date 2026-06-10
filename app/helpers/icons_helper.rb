module IconsHelper
  # Lucide icon names for budget categories
  # All icons are from Lucide library: https://lucide.dev/icons
  ICONS_LIBRARY = {
    # Home & Living
    "home" => "house",
    "sofa" => "sofa",
    "lamp-desk" => "lamp-desk",
    "bed" => "bed",
    "armchair" => "armchair",
    "refrigerator" => "refrigerator",
    "microwave" => "microwave",
    "washing-machine" => "washing-machine",

    # Shopping & Groceries
    "shopping-cart" => "shopping-cart",
    "shopping-bag" => "shopping-bag",
    "shopping-basket" => "shopping-basket",
    "gift" => "gift",
    "package" => "package",

    # Food & Dining
    "pizza" => "pizza",
    "utensils" => "utensils",
    "utensils-crossed" => "utensils-crossed",
    "restaurant" => "chef-hat",
    "cake" => "cake",
    "egg" => "egg",
    "salad" => "salad",
    "sandwich" => "sandwich",
    "soup" => "soup",

    # Beverages
    "coffee" => "coffee",
    "milk" => "milk",
    "wine" => "wine",
    "beer" => "beer",
    "martini" => "martini",

    # Transportation
    "car" => "car",
    "bus" => "bus",
    "train" => "train-front",
    "plane" => "plane",
    "taxi" => "car-taxi-front",
    "truck" => "truck",
    "bike" => "bike",
    "fuel" => "fuel",

    # Finance & Money
    "credit-card" => "credit-card",
    "wallet" => "wallet",
    "coins" => "coins",
    "banknote" => "banknote",
    "receipt" => "receipt",
    "piggy-bank" => "piggy-bank",
    "landmark" => "landmark",
    "chart-bar" => "chart-bar",
    "briefcase" => "briefcase",

    # Entertainment
    "film" => "film",
    "music" => "music",
    "ticket" => "ticket",
    "gamepad-2" => "gamepad-2",
    "tv" => "tv",
    "camera" => "camera",

    # Health & Fitness
    "heart" => "heart",
    "pill" => "pill",
    "dumbbell" => "dumbbell",
    "hospital" => "hospital",
    "stethoscope" => "stethoscope",
    "syringe" => "syringe",

    # Education & Books
    "book" => "book",
    "book-open" => "book-open",
    "graduation-cap" => "graduation-cap",
    "library" => "library",
    "pencil" => "pencil",

    # Personal & Lifestyle
    "sparkles" => "sparkles",
    "star" => "star",
    "scissors" => "scissors",
    "smartphone" => "smartphone",
    "wifi" => "wifi",
    "wrench" => "wrench",
    "shirt" => "shirt",
    "watch" => "watch",
    "glasses" => "glasses",

    # Pets & Animals
    "dog" => "dog",
    "cat" => "cat",
    "bird" => "bird",
    "fish" => "fish",

    # Travel & Location
    "globe" => "globe",
    "map" => "map",
    "map-pin" => "map-pin",
    "compass" => "compass",
    "luggage" => "luggage",

    # Utilities & Services
    "droplet" => "droplet",
    "droplets" => "droplets",
    "flame" => "flame",
    "plug" => "plug",

    # Work & Business
    "laptop" => "laptop",
    "monitor" => "monitor",
    "calculator" => "calculator",

    # Security & Protection
    "shield" => "shield",
    "key" => "key",
    "lock" => "lock",

    # Miscellaneous
    "repeat" => "repeat",
    "arrow-left-right" => "arrow-left-right",
    "square-parking" => "square-parking",
    "umbrella" => "umbrella",

    # Vacation & Travel
    "palmtree" => "tree-palm",
    "hotel" => "hotel",

    # People & Family
    "baby" => "baby",
    "users" => "users",

    # Charity & Community
    "heart-handshake" => "heart-handshake",
    "hand-heart" => "hand-heart",
    "church" => "church",

    # Business & Professional
    "megaphone" => "megaphone",
    "scale" => "scale",
    "user-check" => "user-check",

    # Health & Medical
    "heart-pulse" => "heart-pulse",

    # Documents & Files
    "file-text" => "file-text",

    # Alerts & Status
    "alert-triangle" => "triangle-alert",
    "award" => "award",

    # Other/Generic
    "tag" => "tag",
    "folder" => "folder",
    "circle-dot" => "circle-dot",
    "zap" => "zap"
  }.freeze

  # Lucide SVG markup is identical for a given (icon_name, css_classes) pair and the icon
  # files never change at runtime, so cache the rendered output process-wide. This avoids
  # repeated disk reads when many icons render on one page (e.g. the category dropdown).
  # The cached buffer is frozen so a stray mutation by a caller can never corrupt the shared copy.
  ICON_SVG_CACHE = Concurrent::Map.new
  private_constant :ICON_SVG_CACHE

  IONICON_SAFE_NAMES = %w[home receipt add wallet trending-up].freeze
  IONICON_SAFE_VARIANTS = %w[outline solid].freeze
  private_constant :IONICON_SAFE_NAMES, :IONICON_SAFE_VARIANTS

  # Matches vittio-mobile/src/utils/categoryColors.ts
  CATEGORY_ICON_BG_COLORS = {
    "utensils" => "#f97316",
    "utensils-crossed" => "#f97316",
    "pizza" => "#f97316",
    "chef-hat" => "#f97316",
    "coffee" => "#92400e",
    "car" => "#3b82f6",
    "bus" => "#3b82f6",
    "train-front" => "#3b82f6",
    "plane" => "#3b82f6",
    "fuel" => "#3b82f6",
    "shopping-cart" => "#ec4899",
    "shopping-bag" => "#ec4899",
    "gift" => "#ec4899",
    "film" => "#8b5cf6",
    "music" => "#8b5cf6",
    "ticket" => "#8b5cf6",
    "gamepad-2" => "#8b5cf6",
    "tv" => "#8b5cf6",
    "heart" => "#10b981",
    "pill" => "#10b981",
    "dumbbell" => "#10b981",
    "hospital" => "#10b981",
    "house" => "#84cc16",
    "sofa" => "#84cc16",
    "lamp-desk" => "#84cc16",
    "credit-card" => "#4f46e5",
    "wallet" => "#4f46e5",
    "banknote" => "#4f46e5",
    "landmark" => "#4f46e5",
    "book" => "#06b6d4",
    "book-open" => "#06b6d4",
    "graduation-cap" => "#06b6d4",
    "globe" => "#0ea5e9",
    "luggage" => "#0ea5e9",
    "dog" => "#f59e0b",
    "cat" => "#f59e0b",
    "chart-bar" => "#059669",
    "briefcase" => "#059669",
    "default" => "#94a3b8"
  }.freeze

  def category_icon_bg_color(icon_name)
    CATEGORY_ICON_BG_COLORS[icon_name.to_s.presence || "default"] || CATEGORY_ICON_BG_COLORS["default"]
  end

  def icon_svg(icon_name, css_classes: "w-5 h-5")
    name = icon_name.presence || "tag"
    ICON_SVG_CACHE.compute_if_absent([name, css_classes]) do
      lucide_icon = ICONS_LIBRARY[name] || "tag"
      icon(lucide_icon, library: "lucide", variant: "outline", class: css_classes).to_str.html_safe.freeze
    end
  end

  # Mobile bottom nav — Ionicons SVG files (outline inactive / solid active).
  def ionicon_svg(name, variant: "outline", css_class: "w-[22px] h-[22px]")
    safe_name = name.to_s
    safe_variant = variant.to_s
    return "".html_safe unless IONICON_SAFE_NAMES.include?(safe_name) && IONICON_SAFE_VARIANTS.include?(safe_variant)

    ICON_SVG_CACHE.compute_if_absent([:ionicon, safe_name, safe_variant, css_class]) do
      path = Rails.root.join("app/assets/svg/icons/ionicons/#{safe_variant}/#{safe_name}.svg")
      next "".html_safe.freeze unless File.exist?(path)

      svg = File.read(path)
      rendered = if svg.include?('class="')
        svg.sub(/class="[^"]*"/, "class=\"#{css_class}\"")
      else
        svg.sub("<svg ", "<svg class=\"#{css_class}\" ")
      end
      rendered.html_safe.freeze
    end
  end
end
