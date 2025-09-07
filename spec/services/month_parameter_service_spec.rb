# spec/services/month_parameter_service_spec.rb
require 'rails_helper'

RSpec.describe MonthParameterService do
  describe '.parse_month_param' do
    it 'returns current month beginning when no param is provided' do
      result = described_class.parse_month_param(nil)
      expect(result).to eq(Date.current.beginning_of_month)
    end

    it 'returns current month beginning when empty param is provided' do
      result = described_class.parse_month_param("")
      expect(result).to eq(Date.current.beginning_of_month)
    end

    it 'parses valid YYYY-MM format correctly' do
      result = described_class.parse_month_param("2024-03")
      expect(result).to eq(Date.new(2024, 3, 1))
    end

    it 'parses valid YYYY-MM format with single digit month' do
      result = described_class.parse_month_param("2024-5")
      expect(result).to eq(Date.new(2024, 5, 1))
    end

    it 'handles invalid format gracefully' do
      result = described_class.parse_month_param("invalid-format")
      expect(result).to eq(Date.current.beginning_of_month)
    end

    it 'handles malformed date gracefully' do
      result = described_class.parse_month_param("2024-13") # Invalid month
      expect(result).to eq(Date.current.beginning_of_month)
    end

    it 'handles nil month gracefully' do
      result = described_class.parse_month_param("2024-")
      expect(result).to eq(Date.current.beginning_of_month)
    end

    it 'handles nil year gracefully' do
      result = described_class.parse_month_param("-03")
      expect(result).to eq(Date.current.beginning_of_month)
    end
  end
end
