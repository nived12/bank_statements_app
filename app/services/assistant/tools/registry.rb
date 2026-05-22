# frozen_string_literal: true

module Assistant
  module Tools
    # Central registry: maps tool names to service classes, builds schemas,
    # and dispatches function calls from the LLM.
    module Registry
      TOOL_CLASSES = [
        Assistant::Tools::QueryTransactions,
        Assistant::Tools::GetPeriodSummary,
        Assistant::Tools::ComparePeriods,
        Assistant::Tools::GetLargestTransactions,
        Assistant::Tools::GetAccounts,
        Assistant::Tools::GetNetWorth,
        Assistant::Tools::GetDebts,
        Assistant::Tools::GetSavings,
        Assistant::Tools::GetGoals,
        Assistant::Tools::GetRecurringPayments,
        Assistant::Tools::GetStatementFiles,
        Assistant::Tools::GetCategorySpending
      ].freeze

      # Returns the array of Gemini FunctionDeclaration hashes for all tools.
      def self.declarations
        TOOL_CLASSES.map(&:declaration)
      end

      # Finds and calls a tool by name. Returns a plain Hash.
      # Raises NameError if the tool is not found.
      def self.dispatch(name, user:, **args)
        klass = TOOL_CLASSES.find { |c| c::NAME == name }
        raise NameError, "Unknown tool: #{name}" unless klass

        result = klass.call(user: user, **args)
        result.success? ? result.payload : { error: result.errors.full_messages.to_sentence }
      rescue StandardError => e
        Rails.logger.warn("Tool #{name} raised: #{e.class}: #{e.message}")
        { error: "#{name} failed: #{e.message}" }
      end
    end
  end
end
