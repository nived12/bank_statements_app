# frozen_string_literal: true

# Playwright E2E only — loaded when PLAYWRIGHT_E2E=1 (see db/seeds.rb).
# Keeps automation data separate from the personal dev seed user.

puts "🎭 Seeding Playwright E2E data..."

load(Rails.root.join("db", "seeds_banks.rb")) unless Bank.exists?

E2E_EMAIL = "e2e@example.com"
E2E_PASSWORD = "e2e-test123"

user = User.find_or_initialize_by(email: E2E_EMAIL)
user.assign_attributes(
  first_name: "Playwright",
  last_name: "E2E",
  password: E2E_PASSWORD,
  password_confirmation: E2E_PASSWORD,
  confirmed_at: Time.current,
  legal_version_accepted: "v1.0",
  trial_ends_at: ENV.fetch("TRIAL_DURATION_DAYS", 30).to_i.days.from_now
)
user.save!

# Keep upload quota available for statement_files/new e2e (trial limit = FREE_TIER_STATEMENT_FILES).
if user.statement_files.count >= SubscriptionAccess.free_tier_statement_files
  user.statement_files.destroy_all
end

CategoryTemplate.create_categories_for_user(user) unless user.categories.exists?

bbva_bank = Bank.find_by!(code: "bbva")
banorte_bank = Bank.find_by!(code: "banorte")
santander_bank = Bank.find_by!(code: "santander")

bbva_account = user.bank_accounts.find_or_create_by!(bank: bbva_bank, account_number: "1234") do |account|
  account.currency = "MXN"
  account.opening_balance = -50_000.00
  account.opening_balance_date = Date.current - 30.days
  account.account_type = :credit
  account.custom_name = "BBVA TDC"
end

banorte_account = user.bank_accounts.find_or_create_by!(bank: banorte_bank, account_number: "5678") do |account|
  account.currency = "MXN"
  account.opening_balance = 75_000.00
  account.opening_balance_date = Date.current - 30.days
  account.account_type = :debit
  account.custom_name = "Banorte TDD"
end

santander_account = user.bank_accounts.find_or_create_by!(bank: santander_bank, account_number: "9012") do |account|
  account.currency = "MXN"
  account.opening_balance = 120_000.00
  account.opening_balance_date = Date.current - 30.days
  account.account_type = :debit
  account.custom_name = "Santander TDD"
end

current_month = Date.current.beginning_of_month
income_category = user.categories.find_by(name: "Ingresos")
food_category = user.categories.find_by(name: "Comida")
transport_category = user.categories.find_by(name: "Transporte")
entertainment_category = user.categories.find_by(name: "Entretenimiento")
utilities_category = user.categories.find_by(name: "Servicios")
health_category = user.categories.find_by(name: "Salud")
shopping_category = user.categories.find_by(name: "Compras")

[
  {
    bank_account: bbva_account,
    date: current_month + 5.days,
    description: "Nómina BBVA",
    amount: 25_000.00,
    transaction_type: "income",
    category: income_category&.children&.find_by(name: "Nómina") || income_category
  },
  {
    bank_account: banorte_account,
    date: current_month + 8.days,
    description: "Netflix Subscription",
    amount: -199.00,
    transaction_type: "fixed_expense",
    category: entertainment_category&.children&.find_by(name: "Streaming") || entertainment_category
  },
  {
    bank_account: bbva_account,
    date: current_month + 2.days,
    description: "Supermercado Walmart",
    amount: -1250.50,
    transaction_type: "variable_expense",
    category: food_category&.children&.find_by(name: "Mandado") || food_category
  }
].each do |attrs|
  next if user.transactions.exists?(description: attrs[:description])

  user.transactions.create!(attrs)
end

# Mobile transactions list paginates at 20/page — the infinite-scroll e2e spec
# (mobile-web.spec.ts) hard-fails unless the seed produces enough rows to show
# the scroll trigger and load a second page.
filler_accounts = [bbva_account, banorte_account, santander_account]
filler_categories = [food_category, transport_category, shopping_category, health_category, utilities_category].compact

(1..25).each do |n|
  description = "E2E Filler Transaction #{n}"
  next if user.transactions.exists?(description: description)

  user.transactions.create!(
    bank_account: filler_accounts[n % filler_accounts.size],
    # Dated before the named transactions above so "Netflix Subscription"
    # and "Supermercado Walmart" stay on page 1 (mobile-web.spec.ts looks
    # for them without scrolling/pagination).
    date: current_month - n.days,
    description: description,
    amount: -(50 + n * 10).to_f,
    transaction_type: "variable_expense",
    category: filler_categories[n % filler_categories.size]
  )
end

unless user.recurring_series.exists?(name: "E2E Netflix")
  user.recurring_series.create!(
    name: "E2E Netflix",
    description_signature: "e2e_netflix",
    expected_amount: 199.00,
    frequency: "monthly",
    transaction_type: "fixed_expense",
    next_due_date: Date.current.beginning_of_month + 1.month + 4.days,
    status: "active",
    source: "manual"
  )
end

unless user.savings.exists?(name: "E2E Emergency Fund")
  user.savings.create!(
    name: "E2E Emergency Fund",
    target_amount: 50_000.00,
    current_amount: 10_000.00,
    status: "active"
  )
end

unless user.debts.exists?(name: "E2E Credit Card")
  user.debts.create!(
    name: "E2E Credit Card",
    original_amount: 15_000.00,
    current_balance: 8_500.00,
    interest_rate: 24.0,
    due_day_of_month: 10,
    status: "active"
  )
end

unless user.goals.exists?(name: "E2E Vacation")
  user.goals.create!(
    name: "E2E Vacation",
    goal_type: "savings_goal",
    start_date: Date.current - 30.days,
    deadline: Date.current + 12.months,
    status: "active",
    color: "#6366f1"
  )
end

# Subscription-page states. Deliberately separate users: making the main e2e user
# premium would lift the free-tier gates that the upload and assistant specs rely
# on.
#
# The first two are manual grants — plan name "premium", no Stripe price object —
# so billing_interval is nil and the card renders neither a plan label nor an
# amount. That is the comped-account state.
premium_states = {
  "e2e-premium@example.com" => { ends_at: nil },
  "e2e-canceled@example.com" => { ends_at: 1.year.from_now },
  # An annual subscriber sitting on a price that has since been archived: exactly
  # the production case where the card used to claim "Plan Mensual - MX$99 / mes"
  # for an $1,188/year subscription. Interval and amount both have to come off the
  # synced Stripe object, never from the currently configured price.
  "e2e-legacy-annual@example.com" => {
    ends_at: nil,
    processor_plan: "price_retired_1188",
    current_period_start: 1.month.ago,
    object: {
      "items" => { "data" => [ { "price" => {
        "unit_amount" => 118_800, "currency" => "mxn", "recurring" => { "interval" => "year" }
      } } ] }
    }
  }
}.freeze

premium_states.each do |email, attrs|
  premium_user = User.find_or_initialize_by(email: email)
  premium_user.assign_attributes(
    first_name: "Playwright",
    last_name: "Premium",
    password: E2E_PASSWORD,
    password_confirmation: E2E_PASSWORD,
    confirmed_at: Time.current,
    legal_version_accepted: "v1.0",
    trial_ends_at: nil
  )
  premium_user.save!

  customer = Pay::Customer.find_or_create_by!(owner: premium_user, processor: "stripe") do |c|
    c.processor_id = "manual_e2e_#{premium_user.id}"
  end

  subscription = Pay::Subscription.find_or_initialize_by(
    customer: customer,
    processor_id: "manual_e2e_sub_#{premium_user.id}"
  )
  subscription.assign_attributes(
    name: "premium",
    processor_plan: attrs.fetch(:processor_plan, "premium"),
    quantity: 1,
    status: "active",
    current_period_start: attrs[:current_period_start],
    current_period_end: 1.year.from_now,
    ends_at: attrs[:ends_at],
    object: attrs[:object]
  )
  subscription.save!
end

# Transfer-candidate pair for transfers.spec.ts.
#
# TransferReconciler only considers `source: :statement_file` rows, so a pair created
# through the UI can never produce a candidate — it has to be seeded. Dated two days
# apart on purpose: same-day pairs are auto-linked outright, and it is the *candidate*
# path we need, since that is what was broken (the "N candidatos para revisar" link
# opened nothing). Two days is also the real skew, banks disagreeing about which date
# they print.
transfer_pair = [
  {
    bank_account: banorte_account,
    date: current_month + 10.days,
    description: "E2E SPEI ENVIADO SANTANDER TRANSFERENCIA PROPIA",
    amount: -7_777.00,
    transaction_type: "variable_expense"
  },
  {
    bank_account: santander_account,
    date: current_month + 12.days,
    description: "E2E SPEI RECIBIDO BANORTE TRANSFERENCIA PROPIA",
    amount: 7_777.00,
    transaction_type: "income"
  }
]

transfer_pair.each do |attrs|
  next if user.transactions.exists?(description: attrs[:description])

  user.transactions.create!(attrs.merge(source: :statement_file))
end

puts "✅ Playwright E2E user: #{E2E_EMAIL} / #{E2E_PASSWORD}"
puts "   Subscription states: #{premium_states.keys.join(", ")}"
puts "   Accounts: #{user.bank_accounts.count} | Transactions: #{user.transactions.count}"
puts "   Recurring: #{user.recurring_series.count} | Savings: #{user.savings.count}"
puts "   Debts: #{user.debts.count} | Goals: #{user.goals.count}"
