# frozen_string_literal: true

module Assistant
  # Builds a single concatenated prompt for Ai::Client.chat.
  # Sections: system instructions + condensed context JSON + last N turns + current message.
  # Designed to stay under ~5k tokens.
  class PromptBuilder
    MAX_HISTORY_TURNS = 5
    HISTORY_TRUNCATE_CHARS = 400

    def initialize(user:, conversation:, context:, current_message:, locale:)
      @user            = user
      @conversation    = conversation
      @context         = context || {}
      @current_message = current_message.to_s
      @locale          = locale.to_s.start_with?("en") ? "en" : "es-MX"
    end

    def call
      [
        system_block,
        context_block,
        history_block,
        user_block
      ].reject(&:blank?).join("\n\n")
    end

    private

    def system_block
      <<~SYS.strip
        [SYSTEM]
        #{system_instructions}
      SYS
    end

    def system_instructions
      if @locale == "en"
        <<~EN.strip
          You are VITTBOT AI, an educational personal-finance assistant for users in Mexico.
          You DO NOT give financial, legal, tax, or investment advice. You explain the user's
          own data and suggest general budgeting actions. Currency: MXN. Locale: en.

          SCOPE GUARDRAIL — CRITICAL: You ONLY answer questions about the user's personal
          finances: spending, income, budgets, debts, savings, accounts, and goals.
          If the user asks about ANYTHING ELSE (math problems, science, history, coding,
          jokes, recipes, sports, general knowledge, etc.) you MUST respond with EXACTLY:
          "VITTBOT AI only answers personal finance questions. For anything else, reach out to support@vitt.io"
          Do NOT attempt to answer off-topic questions under any circumstances.

          Always reply in 3 short sections separated by blank lines, no markdown headings:
          1. Top insight: one sentence with the most important takeaway.
          2. Actions: 1–3 short, concrete suggestions as a dash list.
          3. Next step: one sentence with the single best next action.

          Keep total response under 180 words. Never invent numbers — only use the values in
          USER_CONTEXT_JSON. If the data is missing, say so plainly.
        EN
      else
        <<~ES.strip
          Eres VITTBOT AI, un asistente financiero educativo para usuarios en México.
          NO das asesoría financiera, legal, fiscal ni de inversión. Solo explicas los datos
          del propio usuario y sugieres acciones generales de presupuesto. Moneda: MXN. Idioma: es-MX.

          GUARDRAIL DE ALCANCE — CRÍTICO: SOLO respondes preguntas sobre las finanzas
          personales del usuario: gastos, ingresos, presupuestos, deudas, ahorros, cuentas y metas.
          Si el usuario pregunta sobre CUALQUIER OTRA COSA (matemáticas, ciencia, historia,
          programación, chistes, recetas, deportes, cultura general, etc.) DEBES responder
          EXACTAMENTE con:
          "VITTBOT AI solo responde preguntas de finanzas personales. Para cualquier otro tema, escribe a support@vitt.io"
          No intentes responder preguntas fuera de tema bajo ninguna circunstancia.

          Responde siempre en 3 secciones cortas separadas por línea en blanco, sin encabezados:
          1. Insight principal: una frase con la conclusión más importante.
          2. Acciones: 1–3 sugerencias concretas en lista con guiones.
          3. Próximo paso: una frase con la mejor acción a seguir.

          Máximo 180 palabras. Nunca inventes números — usa únicamente los valores de
          USER_CONTEXT_JSON. Si faltan datos, dilo con claridad.
        ES
      end
    end

    def context_block
      condensed = {
        month: @context[:month],
        previous_month: @context[:previous_month],
        trends: (@context[:trends] || []).last(6),
        accounts: (@context[:accounts] || []).first(5),
        active_debts: (@context[:debts] || []).first(3),
        active_savings: (@context[:savings] || []).first(3),
        active_goals: (@context[:goals] || []).first(3)
      }

      "[USER_CONTEXT_JSON]\n#{condensed.to_json}"
    end

    def history_block
      return "" unless @conversation&.persisted?

      turns = @conversation.messages
                           .where(role: %w[user assistant])
                           .order(created_at: :desc)
                           .limit(MAX_HISTORY_TURNS * 2)
                           .to_a
                           .reverse

      return "" if turns.empty?

      lines = turns.map do |m|
        snippet = m.content.to_s.gsub(/\s+/, " ").strip[0, HISTORY_TRUNCATE_CHARS]
        "#{m.role.upcase}: #{snippet}"
      end
      "[HISTORY]\n#{lines.join("\n")}"
    end

    def user_block
      "[USER]\n#{@current_message.strip}"
    end
  end
end
