# frozen_string_literal: true

module Assistant
  # Pure-Ruby intent classifier. Bilingual (es-MX + en). Does NOT call any LLM.
  # Returns { intent:, slots:, path: :deterministic | :llm }.
  #
  # Order of intents in INTENT_PATTERNS matters: first matching pattern wins.
  class IntentRouter
    DETERMINISTIC_INTENTS = %i[
      off_topic
      monthly_summary
      top_categories
      spending_trend
      debt_payoff
      goal_progress
      account_balance
      category_compare
    ].freeze

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
        /capital\s+(de|of)\s+\w+/i,
        /cu[aá]ndo\s+naci[oó]|when\s+was\s+.{1,40}\s+born/i,
        /qui[eé]n\s+(invent[oó]|descubri[oó]|fund[oó])|who\s+(invented|discovered|founded)/i,
        /historia\s+de\s+(la\s+)?(?!mi\s+cuenta|mis\s+transacc|la\s+deuda|el\s+pr[eé]stamo)/i,
        /history\s+of\s+(?!my\s|spending|budget|debt)/i,
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
        /saldo\s+(de\s+(mi\s+)?cuenta)?/i,
        /(my\s+)?balance|how\s+much\s+(do\s+i\s+have|is\s+in)/i
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
      # llm_freeform patterns first since "cómo reducir gasto en categoría X" should
      # NOT match top_categories. Iterate keys in insertion order.
      INTENT_PATTERNS.each do |intent, patterns|
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
