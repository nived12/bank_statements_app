# app/services/parser_factory_service.rb
class ParserFactoryService
  def self.create_parser(parser_type)
    case parser_type
    when "bbva"
      PdfParser::BbvaCreditCard.new
    when "santander", "banorte", "banamex"
      PdfParser::Generic.new
    else
      PdfParser::Generic.new
    end
  end

  def self.get_parser_class(parser_type)
    case parser_type
    when "bbva"
      PdfParser::BbvaCreditCard
    when "santander", "banorte", "banamex"
      PdfParser::Generic
    else
      PdfParser::Generic
    end
  end

  def self.get_parsing_strategy(parser_type)
    case parser_type
    when "bbva"
      :hybrid  # BBVA uses hybrid approach (parser + AI enhancement)
    when "santander", "banorte", "banamex"
      :ai_first  # These banks use AI-first approach
    else
      :parser_first  # Generic banks use parser-first approach
    end
  end
end
