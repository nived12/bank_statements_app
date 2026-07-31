# frozen_string_literal: true

# Seeds realistic demo data for the app-store reviewer account.
#
# App Store and Play Console reviewers sign in with the credentials we submit.
# An empty account shows empty states everywhere and does not match our store
# screenshots, which reads as a broken app. This fills the account with a few
# months of plausible MXN activity.
#
#   bin/rails "reviewer:seed"                      # defaults to test@vitt.io
#   bin/rails "reviewer:seed[other@example.com]"
#   RESET=yes bin/rails "reviewer:seed"            # wipe existing data first
#
# Idempotent: refuses to run twice unless RESET=yes. Deterministic (fixed RNG
# seed), so re-running produces the same data.
namespace :reviewer do
  DEFAULT_REVIEWER_EMAIL = "test@vitt.io"
  MONTHS_OF_HISTORY = 3
  RNG_SEED = 20_260_730

  REVIEWER_ACCOUNTS = [
    {
      bank_code: "bbva", account_number: "4152", custom_name: "BBVA Débito",
      account_type: "debit", opening_balance: 18_400.00
    },
    {
      bank_code: "banorte", account_number: "8871", custom_name: "Banorte Nómina",
      account_type: "debit", opening_balance: 6_250.00
    },
    {
      bank_code: "bbva", account_number: "9038", custom_name: "BBVA Oro TDC",
      account_type: "credit", opening_balance: -12_780.00
    }
  ].freeze

  MONTHLY_INCOME = [
    { day: 15, description: "Depósito de nómina", merchant: "Nómina",  category: "Salario",  amount: 24_500.00 },
    { day: 30, description: "Depósito de nómina", merchant: "Nómina",  category: "Salario",  amount: 24_500.00 },
    { day: 8,  description: "Proyecto freelance", merchant: "Upwork",  category: "Freelance", amount: 7_800.00 }
  ].freeze

  MONTHLY_FIXED = [
    { day: 3,  description: "Renta departamento", merchant: "Arrendador", category: "Alquiler",   amount: -11_500.00 },
    { day: 5,  description: "Internet Totalplay", merchant: "Totalplay",  category: "Internet",   amount: -629.00 },
    { day: 7,  description: "Telcel plan celular", merchant: "Telcel",    category: "Telefonía",  amount: -449.00 },
    { day: 10, description: "CFE electricidad",   merchant: "CFE",        category: "Electricidad", amount: -812.00 },
    { day: 12, description: "Gimnasio Smart Fit", merchant: "Smart Fit", category: "Gimnasio y Fitness",
      amount: -399.00 },
    { day: 14, description: "Suscripción Netflix", merchant: "Netflix", category: "Entretenimiento",
      amount: -299.00 },
    { day: 18, description: "Seguro de auto GNP", merchant: "GNP", category: "Seguro de Vehículo",
      amount: -1_240.00 }
  ].freeze

  # description, merchant, category, min, max — sampled a few times per month
  VARIABLE_EXPENSES = [
    ["Compra supermercado", "Walmart",       "Supermercado",   680,  2_400],
    ["Compra supermercado", "Soriana",       "Supermercado",   540,  1_900],
    ["Despensa semanal",    "Chedraui",      "Supermercado",   420,  1_450],
    ["Comida",              "Starbucks",     "Café y Snacks",   85,    260],
    ["Cena",                "Sushi Roll",    "Restaurantes",   310,    980],
    ["Comida corrida",      "La Casa de Toño", "Restaurantes", 140,    420],
    ["Pedido a domicilio",  "Rappi",         "Delivery",       180,    640],
    ["Gasolina",            "Pemex",         "Gasolina",       600,  1_300],
    ["Viaje",               "Uber",          "Taxi y Rideshare", 75,   340],
    ["Farmacia",            "Farmacias del Ahorro", "Medicamentos", 120, 780],
    ["Compra en línea",     "Amazon México", "Tecnología",     350,  3_200],
    ["Ropa",                "Zara",          "Ropa y Calzado", 490,  2_100],
    ["Cine",                "Cinépolis",     "Entretenimiento", 160,   520],
    ["Estacionamiento",     "Estacionamiento Centro", "Estacionamiento", 40, 120]
  ].freeze

  desc "Seed demo data for the store-reviewer account (default: #{DEFAULT_REVIEWER_EMAIL}). RESET=yes to wipe first."
  task :seed, [:email] => :environment do |_t, args|
    email = args[:email].presence || DEFAULT_REVIEWER_EMAIL
    user  = User.find_by(email: email)

    abort "✗ No user with email #{email}" if user.nil?

    # RESET deletes real rows. In production, restrict it to the reviewer account
    # so a stray RESET=yes can't wipe a paying customer's data.
    if ENV["RESET"] == "yes" && Rails.env.production? && email != DEFAULT_REVIEWER_EMAIL
      abort "✗ Refusing to RESET #{email} in production — RESET is limited to #{DEFAULT_REVIEWER_EMAIL}."
    end

    existing = user.transactions.count + user.bank_accounts.count
    if existing.positive? && ENV["RESET"] != "yes"
      abort "✗ #{email} already has data (#{user.bank_accounts.count} accounts, " \
            "#{user.transactions.count} transactions). Re-run with RESET=yes to replace it."
    end

    ActiveRecord::Base.transaction do
      if ENV["RESET"] == "yes" && existing.positive?
        user.transactions.delete_all
        user.bank_accounts.delete_all
        puts "  cleared existing accounts + transactions"
      end

      rng = Random.new(RNG_SEED)
      categories = user.categories.index_by { |c| c.name.downcase }
      lookup = ->(name) { categories[name.to_s.downcase]&.id }

      accounts = REVIEWER_ACCOUNTS.map do |spec|
        bank = Bank.find_by(code: spec[:bank_code])
        raise "Bank #{spec[:bank_code]} not seeded" if bank.nil?

        user.bank_accounts.create!(
          bank: bank,
          account_number: spec[:account_number],
          custom_name: spec[:custom_name],
          account_type: spec[:account_type],
          currency: "MXN",
          opening_balance: spec[:opening_balance],
          opening_balance_date: MONTHS_OF_HISTORY.months.ago.beginning_of_month.to_date
        )
      end
      puts "  created #{accounts.size} bank accounts"

      debit   = accounts.select(&:debit?)
      credit  = accounts.select(&:credit?)
      rows    = []
      today   = Date.current

      # Clamps a day-of-month into a real date and drops anything after today —
      # future-dated transactions look broken to a reviewer. Kept as a lambda
      # rather than a `def`: inside a Rake block, `def` would leak the method
      # onto Object and make it visible to every other task in the process.
      safe_date = lambda do |month, day|
        date = month + [day - 1, month.end_of_month.day - 1].min
        date > today ? nil : date
      end

      (0...MONTHS_OF_HISTORY).each do |offset|
        month = today.beginning_of_month - offset.months

        MONTHLY_INCOME.each do |item|
          date = safe_date.call(month, item[:day])
          next if date.nil?

          rows << {
            bank_account: debit.last, date: date, description: item[:description],
            merchant: item[:merchant], amount: item[:amount],
            transaction_type: "income", category_id: lookup.call(item[:category])
          }
        end

        MONTHLY_FIXED.each do |item|
          date = safe_date.call(month, item[:day])
          next if date.nil?

          rows << {
            bank_account: debit.first, date: date, description: item[:description],
            merchant: item[:merchant], amount: item[:amount],
            transaction_type: "fixed_expense", category_id: lookup.call(item[:category])
          }
        end

        # 18–24 variable expenses per month, split between debit and credit
        rng.rand(18..24).times do
          desc, merchant, category, min, max = VARIABLE_EXPENSES[rng.rand(VARIABLE_EXPENSES.size)]
          date = safe_date.call(month, rng.rand(1..28))
          next if date.nil?

          account = rng.rand < 0.45 ? credit.first : debit.first
          rows << {
            bank_account: account, date: date, description: desc, merchant: merchant,
            amount: -(rng.rand(min..max).to_d + (rng.rand(100).to_d / 100)),
            transaction_type: "variable_expense", category_id: lookup.call(category)
          }
        end
      end

      rows.each do |row|
        user.transactions.create!(
          bank_account: row[:bank_account],
          date: row[:date],
          description: row[:description],
          merchant: row[:merchant],
          amount: row[:amount],
          transaction_type: row[:transaction_type],
          category_id: row[:category_id],
          source: :manual
        )
      end

      uncategorized = rows.count { |r| r[:category_id].nil? }
      puts "  created #{rows.size} transactions (#{uncategorized} without a category match)"
    end

    user.reload
    puts "\n✓ Seeded #{email}"
    puts "  accounts:     #{user.bank_accounts.count}"
    puts "  transactions: #{user.transactions.count}"
    puts "  date range:   #{user.transactions.minimum(:date)} → #{user.transactions.maximum(:date)}"
    puts "  premium:      #{user.active_paid_subscription? ? "active" : "NOT ACTIVE — reviewer will be gated"}"
  end
end
