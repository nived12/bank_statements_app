# frozen_string_literal: true

module Assistant
  # Pure-Ruby intent classifier. Bilingual (es-MX + en). Does NOT call any LLM.
  # Returns { intent:, slots:, path: :deterministic | :llm }.
  #
  # Order of intents in INTENT_PATTERNS matters: first matching pattern wins.
  class IntentRouter
    DETERMINISTIC_INTENTS = %i[
      greeting
      thanks
      identity
      capabilities
      off_topic
      monthly_summary
      top_categories
      spending_trend
      debt_payoff
      goal_progress
      account_balance
      category_compare
    ].freeze

    CONVERSATIONAL_INTENTS = %i[greeting thanks identity capabilities].freeze

    # Spanish finance vocabulary that must NOT trigger the "historia de" off-topic
    # block (e.g. "historia de mis gastos" is a legitimate finance question).
    HISTORIA_FINANCE_NEGATIVE_LOOKAHEAD = %w[
      mi\\s+cuenta mis\\s+transacc mis\\s+gastos mi\\s+ahorro mi\\s+meta
      mi\\s+tarjeta mi\\s+inversi[oó]n mi\\s+presupuesto la\\s+deuda el\\s+pr[eé]stamo
    ].join("|").freeze

    # Country / place names that COUNT as off-topic when paired with "capital de"
    # (but not when paired with a finance noun like "mi inversión").
    CAPITAL_COUNTRIES = %w[
      m[eé]xico estados\\s+unidos francia jap[oó]n china espa[nñ]a argentina
      brasil alemania italia reino\\s+unido colombia chile peru
    ].freeze
    CAPITAL_COUNTRY_OR_PROPER = "(?:#{CAPITAL_COUNTRIES.join("|")}|[A-ZÁÉÍÓÚÑ][a-záéíóúñ]+)".freeze
    CAPITAL_FINANCE_NEGATIVE_LOOKAHEAD = "(?!mi\\s|trabajo|inversi|pr[eé]stamo|propio|social)".freeze

    INTENT_PATTERNS = {
      # Off-topic: non-finance questions intercepted before reaching the LLM
      off_topic: [
        # Math operations
        /ra[ií]z\s+(cuadrada|c[uú]bica)|square\s+root|cube\s+root/i,
        /logaritmo|logarithm|factorial\b/i,
        /derivada\s+de|integral\s+de|c[aá]lculo\s+diferencial|trigonometr/i,
        /\bseno\b|\bcoseno\b|\btangente\b|\bsine\b|\bcosine\b/i,
        # Programming / code
        /c[oó]mo\s+(programar|escribir|correr)\s+c[oó]digo/i,
        /\b(python|javascript|ruby\s+code|java\s+code|html\s+code)\b.*\b(c[oó]digo|ejemplo|snippet)\b/i,
        # General knowledge / trivia
        # capital + country/place name, but NOT financial uses ("capital de trabajo",
        # "capital de mi inversión", "capital social", etc.)
        Regexp.new("capital\\s+(de|of)\\s+#{CAPITAL_FINANCE_NEGATIVE_LOOKAHEAD}#{CAPITAL_COUNTRY_OR_PROPER}"),
        /cu[aá]ndo\s+naci[oó]|when\s+was\s+.{1,40}\s+born/i,
        /qui[eé]n\s+(invent[oó]|descubri[oó]|fund[oó])|who\s+(invented|discovered|founded)/i,
        # "historia de X" — block only when X is clearly non-finance.
        Regexp.new("historia\\s+de\\s+(la\\s+)?(?!#{HISTORIA_FINANCE_NEGATIVE_LOOKAHEAD})", Regexp::IGNORECASE),
        /history\s+of\s+(?!my\s|spending|budget|debt|savings|investment|expenses|account)/i,
        # Translation requests
        /traduce\s+\S+\s+al\s+\w|translate\s+\S+\s+(to|into)\s+\w/i,
        # Demographics / encyclopedia
        /poblaci[oó]n\s+de\s+\w|population\s+of\s+\w/i,
        # "What is X" for non-finance concepts
        /qu[eé]\s+es\s+(la\s+)?(fotos[ií]ntesis|entrop[ií]a|gravedad|relatividad|democracia|filosof[ií]a)/i,
        # Prompt injection attempts
        /\b(ignore|disregard|forget)\s+(previous|prior|above|all)\s+(instructions|prompt|rules)/i,
        /ignora\s+(las\s+)?(instrucciones|reglas)\s+(anteriores|previas|de\s+arriba)/i,
        # Jokes / stories
        /\bchiste\b|\bch[aá]scarro\b|\bjoke\b/i,
        /cu[eé]ntame\s+(un\s+)?(cuento|historia\s+de\s+ficci[oó]n)/i,
        /tell\s+me\s+a\s+(joke|story\s+about\s+(?!my\s+finance))/i,
        # Recipes / cooking (but not spending on food)
        /receta\s+(de|para)\s+\w/i,
        /recipe\s+for\b/i,
        /c[oó]mo\s+(cocinar|preparar|hacer)\s+\w+(torta|pizza|pasta|pollo\s+frito|cake|tacos)/i,
        # Weather
        /clima\s+(de|en)\s+\w|weather\s+(in|of|forecast)\b/i,
        # Sports scores
        /resultado\s+del?\s+(partido|juego|match)/i,
        /score\s+of\s+the\s+(game|match)/i
      ],
      # "How can I reduce X / save / get better / 7-day plan / advice" — LLM
      llm_freeform: [
        /c[oó]mo\s+(puedo\s+)?(reduc|ahorr|mejor|optimiz|recort|gastar\s+menos)/i,
        /how\s+(can|do)\s+i\s+(reduce|save|improve|optimi[sz]e|cut)/i,
        /plan\s+(de\s+\d+\s+d[ií]as|for\s+\d+\s+days|of\s+\d+\s+days|semanal|weekly)/i,
        /(dame|d[ée]me|give\s+me)\s+(un\s+)?plan/i,
        /consej|advice|tip|recommendation|sugerencia/i
      ],
      monthly_summary: [
        /qu[eé]\s+(pas[oó]|cambi[oó]|hubo).*(este|el)\s+mes/i,
        /resumen\s+(del\s+)?mes|monthly\s+summary|month\s+summary/i,
        /what.*(changed|happened).*month/i,
        /how\s+was\s+(my|this)\s+month/i
      ],
      top_categories: [
        /(en\s+qu[eé]|d[oó]nde).*(gast|m[aá]s)/i,
        /(cu[aá]l|cuales)\s+es\s+mi\s+(mayor|m[aá]s\s+grande)\s+gasto/i,
        /categor[ií]a.*(mayor|m[aá]s)/i,
        /where.*spend.*most|top\s+(spending|categor)/i,
        /biggest\s+expense/i
      ],
      spending_trend: [
        /c[oó]mo\s+va\s+(mi\s+)?(gasto|tendencia)/i,
        /tendencia\s+de\s+(mi\s+)?gasto/i,
        /spending\s+trend|trend\s+of\s+(my\s+)?spending/i,
        /am\s+i\s+spending\s+more/i
      ],
      debt_payoff: [
        /cu[aá]ndo\s+(termino|acabo|termin[oó])\s+de\s+pag/i,
        /cu[aá]ndo.*pag.*deuda/i,
        /payoff\s+date|when.*pay\s+off|when\s+will\s+i\s+finish\s+paying/i
      ],
      goal_progress: [
        /cu[aá]nto\s+(me\s+)?falta\s+(para\s+)?(mi\s+)?meta/i,
        /c[oó]mo\s+va\s+(mi\s+)?meta/i,
        /how\s+(much|close).*goal|goal\s+progress/i
      ],
      account_balance: [
        /cu[aá]l\s+es\s+mi\s+saldo|cu[aá]nto\s+tengo/i,
        /\bsaldo\s+(de\s+(mi\s+)?cuenta|disponible|actual)/i,
        /\bmy\s+balance\b|\bbalance\s+of\s+my\b|how\s+much\s+(do\s+i\s+have|is\s+in)/i
      ],
      category_compare: [
        /compar(a|ar|aci[oó]n).*(categor|gasto)/i,
        /compare.*(category|categor[ií]as|spending)/i
      ]
    }.freeze

    def initialize(message:, user:, context: nil)
      @message = message.to_s
      @user    = user
      @context = context || {}
    end

    def call
      intent = detect_intent
      slots  = extract_slots(intent)
      path   = DETERMINISTIC_INTENTS.include?(intent) ? :deterministic : :llm

      { intent: intent, slots: slots, path: path }
    end

    # Class-level convenience for spec table-driven tests.
    def self.classify(message)
      new(message: message, user: nil).call[:intent]
    end

    private

    attr_reader :message, :user, :context

    def detect_intent
      # Off-topic deny-list runs FIRST so mixed messages like
      # "translate hola to French" route to the refusal — not the greeting
      # catalog (which would match on "hola").
      INTENT_PATTERNS[:off_topic].each do |re|
        return :off_topic if message.match?(re)
      end

      # Conversational catalog (greeting / thanks / identity / capabilities).
      # Peer-product UX: instant friendly reply, $0 cost, no LLM call.
      conversational = Assistant::ConversationalMatcher.match(message)
      return conversational if conversational

      # Remaining intents in insertion order. llm_freeform is grouped here so
      # "cómo reducir gasto en categoría X" routes to llm_freeform, not
      # top_categories.
      INTENT_PATTERNS.each do |intent, patterns|
        next if intent == :off_topic # already checked above

        return intent if patterns.any? { |re| message.match?(re) }
      end
      :llm_freeform
    end

    def extract_slots(intent)
      slots = {}
      case intent
      when :debt_payoff
        slots[:debt_id] = fuzzy_match_name(message, user&.debts&.where(status: "active"))
      when :goal_progress
        slots[:goal_id] = fuzzy_match_name(message, user&.goals&.where(status: "active"))
      when :account_balance
        slots[:account_id] = fuzzy_match_name(message, user&.bank_accounts)
      when :top_categories, :category_compare
        slots[:category_id] = fuzzy_match_name(message, user&.categories)
      end
      slots
    end

    # Returns the id of the first record whose downcased name appears in the message.
    # Returns nil if no records or no match.
    def fuzzy_match_name(text, scope, name_attr: :name)
      return nil if scope.nil?

      records = scope.respond_to?(:to_a) ? scope.to_a : Array(scope)
      return nil if records.empty?

      normalized = normalize(text)
      match = records.find do |r|
        name = r.respond_to?(name_attr) ? r.public_send(name_attr).to_s : ""
        next false if name.blank?

        normalized.include?(normalize(name))
      end
      match&.id
    end

    def normalize(str)
      I18n.transliterate(str.to_s).downcase
    end
  end
end
