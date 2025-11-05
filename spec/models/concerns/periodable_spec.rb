# frozen_string_literal: true

require "rails_helper"

RSpec.describe Periodable do
  let(:user) { create(:user) }
  let(:saving) { create(:saving, user: user, target_amount: 10000, current_amount: 0) }

  describe "#progress_for_period" do
    it "calculates progress for a given period" do
      start_date = Date.new(2024, 1, 1)
      end_date = Date.new(2024, 1, 31)

      result = saving.progress_for_period(start_date, end_date)

      expect(result).to include(:achieved, :target, :percentage, :start_date, :end_date)
      expect(result[:start_date]).to eq(start_date)
      expect(result[:end_date]).to eq(end_date)
    end
  end

  describe "#current_month_progress" do
    it "returns progress for current month" do
      result = saving.current_month_progress

      expect(result).to include(:achieved, :target, :percentage)
      expect(result[:start_date]).to eq(Date.current.beginning_of_month)
    end
  end

  describe "#monthly_timeline" do
    it "generates timeline for specified months" do
      timeline = saving.monthly_timeline(3)

      expect(timeline).to be_an(Array)
      expect(timeline.length).to be <= 3
      timeline.each do |period|
        expect(period).to include(:achieved, :target, :percentage, :month)
      end
    end

    it "does not include future months" do
      timeline = saving.monthly_timeline(24)

      future_periods = timeline.select { |p| p[:start_date] > Date.current }
      expect(future_periods).to be_empty
    end
  end
end
