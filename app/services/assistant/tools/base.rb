# frozen_string_literal: true

module Assistant
  module Tools
    # Abstract base class for all Vittbot tools.
    # Subclasses must define:
    #   NAME        - unique snake_case identifier
    #   DESCRIPTION - one-sentence semantic description for the LLM
    #   SCHEMA      - Gemini FunctionDeclaration `parameters` hash
    #
    # Example usage:
    #   Assistant::Tools::GetNetWorth.call(user: user)
    class Base < ApplicationService
      def initialize(user:, **args)
        super()
        @user = user
        @args = args
      end

      def call
        raise NotImplementedError, "#{self.class}#call not implemented"
      end

      # Returns the Gemini FunctionDeclaration hash for this tool.
      def self.declaration
        {
          name: self::NAME,
          description: self::DESCRIPTION,
          parameters: self::SCHEMA
        }
      end
    end
  end
end
