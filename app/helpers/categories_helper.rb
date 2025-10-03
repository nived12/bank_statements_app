module CategoriesHelper
  # Lucide icon names for budget categories
  # All icons are from Lucide library: https://lucide.dev/icons
  CATEGORY_ICONS = {
    # Home & Living
    'home' => 'house',
    'sofa' => 'sofa',
    'lamp-desk' => 'lamp-desk',
    'bed' => 'bed',
    'armchair' => 'armchair',
    'refrigerator' => 'refrigerator',
    'microwave' => 'microwave',
    'washing-machine' => 'washing-machine',

    # Shopping & Groceries
    'shopping-cart' => 'shopping-cart',
    'shopping-bag' => 'shopping-bag',
    'shopping-basket' => 'shopping-basket',
    'gift' => 'gift',
    'package' => 'package',

    # Food & Dining
    'pizza' => 'pizza',
    'utensils' => 'utensils',
    'utensils-crossed' => 'utensils-crossed',
    'restaurant' => 'chef-hat',
    'cake' => 'cake',
    'egg' => 'egg',
    'salad' => 'salad',
    'sandwich' => 'sandwich',
    'soup' => 'soup',

    # Beverages
    'coffee' => 'coffee',
    'milk' => 'milk',
    'wine' => 'wine',
    'beer' => 'beer',
    'martini' => 'martini',

    # Transportation
    'car' => 'car',
    'bus' => 'bus',
    'train' => 'train-front',
    'plane' => 'plane',
    'taxi' => 'car-taxi-front',
    'truck' => 'truck',
    'bike' => 'bike',
    'fuel' => 'fuel',

    # Finance & Money
    'credit-card' => 'credit-card',
    'wallet' => 'wallet',
    'coins' => 'coins',
    'banknote' => 'banknote',
    'receipt' => 'receipt',
    'piggy-bank' => 'piggy-bank',
    'landmark' => 'landmark',
    'chart-bar' => 'chart-bar',
    'briefcase' => 'briefcase',

    # Entertainment
    'film' => 'film',
    'music' => 'music',
    'ticket' => 'ticket',
    'gamepad-2' => 'gamepad-2',
    'tv' => 'tv',
    'camera' => 'camera',

    # Health & Fitness
    'heart' => 'heart',
    'pill' => 'pill',
    'dumbbell' => 'dumbbell',
    'hospital' => 'hospital',
    'stethoscope' => 'stethoscope',
    'syringe' => 'syringe',

    # Education & Books
    'book' => 'book',
    'book-open' => 'book-open',
    'graduation-cap' => 'graduation-cap',
    'library' => 'library',
    'pencil' => 'pencil',

    # Personal & Lifestyle
    'sparkles' => 'sparkles',
    'star' => 'star',
    'scissors' => 'scissors',
    'smartphone' => 'smartphone',
    'wifi' => 'wifi',
    'wrench' => 'wrench',
    'shirt' => 'shirt',
    'watch' => 'watch',
    'glasses' => 'glasses',

    # Pets & Animals
    'dog' => 'dog',
    'cat' => 'cat',
    'bird' => 'bird',
    'fish' => 'fish',

    # Travel & Location
    'globe' => 'globe',
    'map' => 'map',
    'map-pin' => 'map-pin',
    'compass' => 'compass',
    'luggage' => 'luggage',

    # Other/Generic
    'tag' => 'tag',
    'folder' => 'folder',
    'circle-dot' => 'circle-dot',
    'zap' => 'zap'
  }.freeze

  def category_icon_svg(icon_name, css_classes: "w-5 h-5")
    icon_name = icon_name.presence || 'tag'
    lucide_icon = CATEGORY_ICONS[icon_name] || 'tag'

    # Use rails_icons helper with Lucide library
    icon(lucide_icon, library: "lucide", variant: "outline", class: css_classes, fallback: icon("tag", library: "lucide", variant: "outline", class: css_classes))
  end
end
