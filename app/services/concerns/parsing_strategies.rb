# frozen_string_literal: true

##
# ParsingStrategies
# Concern module for different parsing strategies including hybrid, AI-first, parser-first, and generic
#
# Usage:
# include ParsingStrategies in your service class and you can use:
#   result = parse_hybrid(text_chunks, text)
#   result = parse_ai_first(text_chunks, text)
#   result = parse_parser_first(text_chunks, text)
#   result = parse_generic(text_chunks, text)
#
module ParsingStrategies
  private

  def parse_hybrid(text_chunks, text)
    # Try parser first, then enhance with AI if available
    parser_result = parse_with_deterministic_parser(text)

    if parser_result&.dig("transactions")&.any?
      enhance_with_ai_if_available(parser_result)
    else
      # Parser failed, try AI fallback
      ai_fallback_result = parse_with_ai(text_chunks, text)
      if ai_fallback_result
        ai_fallback_result["extraction_source"] = "ai_parser_fallback"
        ai_fallback_result
      else
        empty_result
      end
    end
  end

  def parse_ai_first(text_chunks, text)
    if ai_api_available?
      ai_result = parse_with_ai(text_chunks, text)
      ai_result || parse_with_deterministic_parser(text)
    else
      parse_with_deterministic_parser(text)
    end
  end

  def parse_parser_first(text_chunks, text)
    parser_result = parse_with_deterministic_parser(text)

    if parser_result&.dig("transactions")&.any?
      parser_result
    elsif ai_api_available?
      parse_with_ai(text_chunks, text)
    else
      nil
    end
  end

  def parse_generic(text_chunks, text)
    if ai_api_available?
      parse_with_ai(text_chunks, text)
    else
      parse_with_deterministic_parser(text)
    end
  end

  def enhance_with_ai_if_available(parser_result)
    return parser_result unless ai_api_available?

    ai_result = parse_with_ai_enhancement(parser_result)

    if ai_result&.dig("transactions")&.any?
      merged_result = merge_ai_categorization_with_parser_transactions(parser_result, ai_result)
      merged_result["extraction_source"] = "ai_enhanced_parser"
      merged_result
    else
      parser_result["extraction_source"] = "parser_with_basic_categorization"
      parser_result
    end
  end

  def empty_result
    { "transactions" => [], "financial_summaries" => [] }
  end

  # These methods need to be implemented by the including class
  def parse_with_deterministic_parser(text)
    raise NotImplementedError, "parse_with_deterministic_parser must be implemented"
  end

  def parse_with_ai(text_chunks, text)
    raise NotImplementedError, "parse_with_ai must be implemented"
  end

  def parse_with_ai_enhancement(parser_result)
    raise NotImplementedError, "parse_with_ai_enhancement must be implemented"
  end

  def merge_ai_categorization_with_parser_transactions(parser_result, ai_result)
    raise NotImplementedError, "merge_ai_categorization_with_parser_transactions must be implemented"
  end
end
