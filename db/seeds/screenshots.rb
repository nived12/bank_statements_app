# Screenshot seed — clean data for App Store / Play Store screenshots.
# Run with: rails runner db/seeds/screenshots.rb
# Safe to re-run (idempotent via find_or_create_by).

puts "Setting up screenshot user..."

# ── User ──────────────────────────────────────────────────────────────────────

user = User.find_or_create_by(email: "dev@vitt.io") do |u|
  u.first_name = "Vittio"
  u.last_name  = "Dev"
end

user.update!(
  password:              "Screenshot1!",
  password_confirmation: "Screenshot1!",
  confirmed_at:          Time.current,
  legal_version_accepted: "v1.0"
)

CategoryTemplate.create_categories_for_user(user) if user.categories.none?

puts "  User: #{user.email} (id=#{user.id})"

# ── Premium subscription ───────────────────────────────────────────────────────

unless user.active_paid_subscription?
  pay_customer = Pay::Customer.find_or_create_by!(owner: user, processor: "stripe") do |c|
    c.processor_id = "manual_screenshot_#{user.id}"
  end

  Pay::Subscription.find_or_create_by!(customer: pay_customer, processor_id: "manual_sub_screenshot_#{user.id}") do |s|
    s.name           = "premium"
    s.processor_plan = "premium"
    s.status         = "active"
  end

  puts "  Premium subscription created"
end

# ── Banks ─────────────────────────────────────────────────────────────────────

load(Rails.root.join("db", "seeds_banks.rb")) if Bank.none?

bbva_bank      = Bank.find_by!(code: "bbva")
banorte_bank   = Bank.find_by!(code: "banorte")
nu_bank        = Bank.find_by(code: "nu") || Bank.find_by(code: "nubank") || Bank.first

# ── Bank accounts ─────────────────────────────────────────────────────────────

bbva = user.bank_accounts.find_or_create_by!(custom_name: "BBVA Débito") do |a|
  a.bank                 = bbva_bank
  a.account_number       = "4152"
  a.currency             = "MXN"
  a.opening_balance      = 18_540.00
  a.opening_balance_date = Date.current - 60.days
  a.account_type         = :debit
end

banorte = user.bank_accounts.find_or_create_by!(custom_name: "Banorte TDC") do |a|
  a.bank                 = banorte_bank
  a.account_number       = "7831"
  a.currency             = "MXN"
  a.opening_balance      = -12_300.00
  a.opening_balance_date = Date.current - 60.days
  a.account_type         = :credit
end

nu = user.bank_accounts.find_or_create_by!(custom_name: "Nu Cuenta") do |a|
  a.bank                 = nu_bank || bbva_bank  # fallback if Nu not seeded
  a.account_number       = "0042"
  a.currency             = "MXN"
  a.opening_balance      = 5_200.00
  a.opening_balance_date = Date.current - 60.days
  a.account_type         = :debit
end

puts "  #{user.bank_accounts.count} bank accounts"

# ── Statement files (bypassed validation — no real PDF needed) ─────────────────

def find_or_create_statement(user:, bank_account:, days_ago:, deposits:, withdrawals:)
  StatementFile.where(user: user, bank_account: bank_account).first_or_initialize.tap do |sf|
    sf.parsed_json   = {}
    sf.redaction_map = {}
    sf.status        = :completed
    sf.processed_at  = days_ago.days.ago
    sf.save!(validate: false)

    unless sf.financial_summary
      sf.create_financial_summary!(
        statement_type:      "savings",
        statement_type_data: { "total_deposits" => deposits, "total_withdrawals" => withdrawals },
        initial_balance:     bank_account.opening_balance.to_f,
        final_balance:       bank_account.opening_balance.to_f + deposits - withdrawals,
        statement_period_start: 1.month.ago.beginning_of_month,
        statement_period_end:   1.month.ago.end_of_month,
        days_in_period:      30
      )
    end
  end
end

bbva_sf    = find_or_create_statement(
  user: user, bank_account: bbva,    days_ago: 2, deposits: 32_000,
  withdrawals: 14_500
)
banorte_sf = find_or_create_statement(
  user: user, bank_account: banorte, days_ago: 3, deposits:  5_000,
  withdrawals:  8_200
)
nu_sf      = find_or_create_statement(
  user: user, bank_account: nu,      days_ago: 4, deposits: 10_000,
  withdrawals:  3_100
)

# ── Category helpers ───────────────────────────────────────────────────────────

def cat(user, name, child: nil)
  parent = user.categories.find_by(name: name)
  return parent unless child

  parent&.children&.find_by(name: child) || parent
end

# ── Transactions — current month ──────────────────────────────────────────────

today   = Date.current
m_start = today.beginning_of_month

def tx_exists?(user, description, date)
  user.transactions.exists?(description: description, date: date)
end

current_month_txs = [
  # Income
  { bank_account: bbva,    sf: bbva_sf,    date: m_start + 1,  description: "Nómina Enero",
amount:  28_000.00, type: "income",           cat: cat(user, "Ingresos", child: "Nómina") },
  { bank_account: nu,      sf: nu_sf,      date: m_start + 3,  description: "Freelance — Diseño web",
amount:  12_500.00, type: "income",           cat: cat(user, "Ingresos", child: "Freelance") },
  # Food
  { bank_account: bbva,    sf: bbva_sf,    date: m_start + 2,  description: "Walmart Supercenter",
amount:  -1_420.50, type: "variable_expense", cat: cat(user, "Comida",       child: "Mandado") },
  { bank_account: bbva,    sf: bbva_sf,    date: m_start + 4,  description: "Starbucks",
amount:    -145.00, type: "variable_expense", cat: cat(user, "Comida",       child: "Cafeterías") },
  { bank_account: banorte, sf: banorte_sf, date: m_start + 5,  description: "Restaurante Toks",
amount:    -580.00, type: "variable_expense", cat: cat(user, "Comida",       child: "Restaurantes") },
  { bank_account: bbva,    sf: bbva_sf,    date: m_start + 8,  description: "Soriana Mercado",
amount:    -890.00, type: "variable_expense", cat: cat(user, "Comida",       child: "Mandado") },
  { bank_account: nu,      sf: nu_sf,      date: m_start + 11, description: "McDonald's",
amount:    -210.00, type: "variable_expense", cat: cat(user, "Comida",       child: "Restaurantes") },
  # Transport
  { bank_account: bbva,    sf: bbva_sf,    date: m_start + 3,  description: "Gasolina Pemex",
amount:    -950.00, type: "variable_expense", cat: cat(user, "Transporte",   child: "Gasolina") },
  { bank_account: banorte, sf: banorte_sf, date: m_start + 6,  description: "Uber - Aeropuerto",
amount:    -340.00, type: "variable_expense", cat: cat(user, "Transporte",   child: "Uber/Didi") },
  { bank_account: nu,      sf: nu_sf,      date: m_start + 9,  description: "Uber - Centro",
amount:    -125.00, type: "variable_expense", cat: cat(user, "Transporte",   child: "Uber/Didi") },
  # Fixed
  { bank_account: bbva,    sf: bbva_sf,    date: m_start + 1,  description: "Renta Departamento",
amount:  -9_500.00, type: "fixed_expense",    cat: cat(user, "Vivienda",     child: "Renta") },
  { bank_account: banorte, sf: banorte_sf, date: m_start + 2,  description: "CFE Luz",
amount:    -780.00, type: "fixed_expense",    cat: cat(user, "Servicios",    child: "Luz") },
  { bank_account: banorte, sf: banorte_sf, date: m_start + 2,  description: "Telmex Internet",
amount:    -499.00, type: "fixed_expense",    cat: cat(user, "Servicios",    child: "Internet") },
  { bank_account: nu,      sf: nu_sf,      date: m_start + 4,  description: "Netflix",
amount:    -199.00, type: "fixed_expense",    cat: cat(user, "Entretenimiento", child: "Streaming") },
  { bank_account: nu,      sf: nu_sf,      date: m_start + 4,  description: "Spotify",
amount:     -99.00, type: "fixed_expense",    cat: cat(user, "Entretenimiento", child: "Streaming") },
  # Health / Shopping
  { bank_account: bbva,    sf: bbva_sf,    date: m_start + 7,  description: "Farmacia del Ahorro",
amount:    -430.00, type: "variable_expense", cat: cat(user, "Salud",        child: "Farmacia") },
  { bank_account: banorte, sf: banorte_sf, date: m_start + 10, description: "Zara — Chamarra",
amount:  -1_590.00, type: "variable_expense", cat: cat(user, "Compras",      child: "Ropa") },
  { bank_account: bbva,    sf: bbva_sf,    date: m_start + 12, description: "Amazon — Audífonos",
amount:    -899.00, type: "variable_expense", cat: cat(user, "Compras",      child: "Electrónica") }
]

current_month_txs.each do |t|
  next if tx_exists?(user, t[:description], t[:date])

  user.transactions.create!(
    bank_account:     t[:bank_account],
    statement_file:   t[:sf],
    date:             t[:date],
    description:      t[:description],
    amount:           t[:amount],
    transaction_type: t[:type],
    category:         t[:cat]
  )
end

# ── Transactions — 5 previous months ──────────────────────────────────────────

recurring_merchants = [
  ["Walmart Supercenter", -1_300, "variable_expense", "Comida",          "Mandado"],
  ["Gasolina Pemex",        -900, "variable_expense", "Transporte",      "Gasolina"],
  ["Netflix",               -199, "fixed_expense",    "Entretenimiento", "Streaming"],
  ["Spotify",                -99, "fixed_expense",    "Entretenimiento", "Streaming"],
  ["CFE Luz",               -750, "fixed_expense",    "Servicios",       "Luz"],
  ["Telmex Internet",       -499, "fixed_expense",    "Servicios",       "Internet"],
  ["Renta Departamento", -9_500,  "fixed_expense",    "Vivienda",        "Renta"],
  ["Uber - Centro",         -180, "variable_expense", "Transporte",      "Uber/Didi"],
  ["Farmacia del Ahorro",   -380, "variable_expense", "Salud",           "Farmacia"],
  ["Restaurante Toks",      -520, "variable_expense", "Comida",          "Restaurantes"],
  ["Nómina Enero",        28_000, "income",           "Ingresos",        "Nómina"]
]

(1..5).each do |offset|
  month_start = today.beginning_of_month - offset.months

  recurring_merchants.each_with_index do |(desc, amount, type, parent, child), idx|
    day   = (idx * 3 + 1).clamp(1, 27)
    date  = month_start + day.days
    next if tx_exists?(user, desc, date)

    accounts = [bbva, banorte, nu]
    account  = accounts[idx % 3]
    sf       = [bbva_sf, banorte_sf, nu_sf][idx % 3]

    user.transactions.create!(
      bank_account:     account,
      statement_file:   sf,
      date:             date,
      description:      desc,
      amount:           amount,
      transaction_type: type,
      category:         cat(user, parent, child: child)
    )
  end
end

puts "  #{user.transactions.count} transactions"

# ── Savings ────────────────────────────────────────────────────────────────────

unless user.savings.any?
  emergency = user.savings.create!(
    name:           "Fondo de emergencia",
    target_amount:  50_000.00,
    current_amount: 18_500.00,
    status:         "active"
  )

  SavingTransaction.create!(
    saving:           emergency,
    bank_account:     bbva,
    user:             user,
    amount:           18_500.00,
    transaction_type: "deposit",
    date:             Date.current - 45.days,
    notes:            "Depósito inicial"
  )

  vacation = user.savings.create!(
    name:           "Viaje Japón",
    target_amount:  80_000.00,
    current_amount: 12_000.00,
    status:         "active"
  )

  SavingTransaction.create!(
    saving:           vacation,
    bank_account:     nu,
    user:             user,
    amount:           12_000.00,
    transaction_type: "deposit",
    date:             Date.current - 30.days,
    notes:            "Primer ahorro"
  )

  puts "  #{user.savings.count} savings"
end

# ── Debts ──────────────────────────────────────────────────────────────────────

unless user.debts.any?
  tarjeta = user.debts.create!(
    name:            "Tarjeta Banorte TDC",
    original_amount: 22_000.00,
    current_balance: 12_300.00,
    interest_rate:   36.0,
    due_day_of_month: 15,
    status:          "active"
  )

  DebtTransaction.create!(
    debt:             tarjeta,
    bank_account:     bbva,
    user:             user,
    amount:           9_700.00,
    transaction_type: "payment",
    date:             Date.current - 20.days,
    notes:            "Abono mensual"
  )

  puts "  #{user.debts.count} debts"
end

# ── Goals ──────────────────────────────────────────────────────────────────────

unless user.goals.any?
  emergency_saving = user.savings.find_by(name: "Fondo de emergencia")
  vacation_saving  = user.savings.find_by(name: "Viaje Japón")

  if emergency_saving
    goal = user.goals.create!(
      name:      "Fondo de emergencia",
      goal_type: "savings_goal",
      start_date: Date.current - 45.days,
      deadline:  Date.current + 8.months,
      status:    "active",
      color:     "#10b981"
    )
    GoalSaving.create!(goal: goal, saving: emergency_saving)
  end

  if vacation_saving
    goal2 = user.goals.create!(
      name:      "Viaje a Japón",
      goal_type: "savings_goal",
      start_date: Date.current - 30.days,
      deadline:  Date.current + 14.months,
      status:    "active",
      color:     "#6366f1"
    )
    GoalSaving.create!(goal: goal2, saving: vacation_saving)
  end

  debt = user.debts.first
  if debt
    goal3 = user.goals.create!(
      name:      "Liquidar Tarjeta Banorte",
      goal_type: "debt_payoff",
      start_date: Date.current - 20.days,
      deadline:  Date.current + 18.months,
      status:    "active",
      color:     "#ef4444"
    )
    GoalDebt.create!(goal: goal3, debt: debt)
  end

  puts "  #{user.goals.count} goals"
end

# ── Recurring series ───────────────────────────────────────────────────────────

unless user.recurring_series.any?
  [
    { name: "Renta Departamento", amount: 9_500.00,  type: "fixed_expense", sig: "renta_departamento",  due_offset: 1 },
    { name: "Netflix",            amount:   199.00,  type: "fixed_expense", sig: "netflix",             due_offset: 4 },
    { name: "Spotify",            amount:    99.00,  type: "fixed_expense", sig: "spotify",             due_offset: 4 },
    { name: "Telmex Internet",    amount:   499.00,  type: "fixed_expense", sig: "telmex_internet",     due_offset: 2 },
    { name: "Nómina",             amount: 28_000.00, type: "income",        sig: "nomina",              due_offset: 1 }
  ].each do |attrs|
    user.recurring_series.create!(
      name:                  attrs[:name],
      description_signature: attrs[:sig],
      expected_amount:       attrs[:amount],
      frequency:             "monthly",
      transaction_type:      attrs[:type],
      next_due_date:         today.beginning_of_month + 1.month + attrs[:due_offset].days,
      status:                "active",
      source:                "manual"
    )
  end
  puts "  #{user.recurring_series.count} recurring series"
end

# ── Assistant conversation ─────────────────────────────────────────────────────

unless user.assistant_conversations.any?
  conv = user.assistant_conversations.create!(
    title:           "Análisis de gastos",
    locale:          "es-MX",
    last_message_at: 2.hours.ago,
    message_count:   4,
    disclaimer_shown: true
  )

  [
    {
      role:    "user",
      content: "¿Cuánto gasté en comida este mes?",
      intent:  "spending_by_category"
    },
    {
      role:    "assistant",
      content: "Este mes llevas **$3,244.50 MXN** en comida — un 18% de tu gasto total. Tu categoría más alta es Mandado ($2,310.50), seguida de Restaurantes ($580) y Cafeterías ($145).\n\n📊 Comparado con tu promedio de los últimos 3 meses ($3,010), estás un poco arriba. ¿Quieres ver dónde podrías recortar?",
      intent:  "spending_by_category"
    },
    {
      role:    "user",
      content: "¿En qué puedo ahorrar más?",
      intent:  "coaching"
    },
    {
      role:    "assistant",
      content: "Con base en tus últimos 3 meses, hay 3 áreas con margen real:\n\n1. **Restaurantes y cafeterías** — gastas ~$725/mes en promedio. Cocinar 2 veces más por semana podría ahorrarte $200-300/mes.\n2. **Streaming** — tienes Netflix + Spotify ($298/mes). Si compartes cuenta de Netflix, te queda solo Spotify.\n3. **Gasolina** — fluctúa entre $800-1,100/mes. Agrupar viajes en días específicos te puede bajar ~$150.\n\nPotencial de ahorro: **$600-750/mes** sin cambios drásticos.",
      intent:  "coaching"
    }
  ].each_with_index do |msg, idx|
    conv.messages.create!(
      user:            user,
      role:            msg[:role],
      content:         msg[:content],
      intent:          msg[:intent],
      is_deterministic: false,
      created_at:      2.hours.ago + (idx * 15).minutes,
      updated_at:      2.hours.ago + (idx * 15).minutes
    )
  end

  puts "  Assistant conversation with #{conv.messages.count} messages"
end

# ── Summary ────────────────────────────────────────────────────────────────────

puts "\n✅ Screenshot seed complete!"
puts "   Email:    dev@vitt.io"
puts "   Password: Screenshot1!"
puts "   Premium:  #{user.active_paid_subscription? ? "YES" : "NO"}"
puts "   Accounts: #{user.bank_accounts.count}"
puts "   Transactions: #{user.transactions.count}"
puts "   Savings: #{user.savings.count} | Debts: #{user.debts.count} | Goals: #{user.goals.count}"
puts "   Recurring: #{user.recurring_series.count}"
puts "   Assistant conversations: #{user.assistant_conversations.count}"
