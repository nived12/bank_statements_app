# frozen_string_literal: true

require "rails_helper"

RSpec.describe UserSettings, type: :model do
  describe "associations" do
    it "belongs to user" do
      settings = build(:user_settings)
      expect(settings.user).to be_present
    end
  end

  describe "validations" do
    it "validates uniqueness of user_id" do
      user = create(:user)
      # User already has user_settings from after_create callback
      duplicate = build(:user_settings, user: user)
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:user_id]).to be_present
    end

    context "preferences validation" do
      let(:user) { create(:user) }

      it "allows valid preference keys" do
        # Update existing user_settings instead of creating new one
        user.user_settings.update(preferences: { "processing_strategy" => "text_with_ai" })
        expect(user.user_settings.reload).to be_valid
      end

      it "rejects invalid preference keys" do
        user.user_settings.preferences = { "invalid_key" => "value" }
        expect(user.user_settings).not_to be_valid
        expect(user.user_settings.errors[:preferences]).to include("contains invalid keys: invalid_key")
      end

      it "allows empty preferences" do
        user.user_settings.update(preferences: {})
        expect(user.user_settings.reload).to be_valid
      end
    end
  end

  describe "#processing_strategy" do
    let(:user) { create(:user) }

    it "returns the processing_strategy from preferences" do
      user.user_settings.update(preferences: { "processing_strategy" => "vision_ai" })
      expect(user.user_settings.processing_strategy).to eq("vision_ai")
    end

    it "returns parser_only as default when not set" do
      user.user_settings.update(preferences: {})
      expect(user.user_settings.processing_strategy).to eq("parser_only")
    end
  end

  describe "#processing_strategy=" do
    let(:user) { create(:user) }

    it "sets the processing_strategy in preferences" do
      user.user_settings.processing_strategy = "text_with_ai"
      expect(user.user_settings.preferences["processing_strategy"]).to eq("text_with_ai")
    end

    it "preserves other preferences" do
      user.user_settings.preferences = {}
      user.user_settings.processing_strategy = "vision_ai"
      expect(user.user_settings.preferences).to eq({ "processing_strategy" => "vision_ai" })
    end
  end

  describe "#theme" do
    let(:user) { create(:user) }

    it "returns the theme from preferences" do
      user.user_settings.update(preferences: { "theme" => "dark" })
      expect(user.user_settings.theme).to eq("dark")
    end

    it "returns light as default when not set" do
      user.user_settings.update(preferences: {})
      expect(user.user_settings.theme).to eq("light")
    end
  end

  describe "#theme=" do
    let(:user) { create(:user) }

    it "sets the theme in preferences" do
      user.user_settings.theme = "dark"
      expect(user.user_settings.preferences["theme"]).to eq("dark")
    end

    it "preserves other preferences" do
      user.user_settings.preferences = { "processing_strategy" => "vision_ai" }
      user.user_settings.theme = "light"
      expect(user.user_settings.preferences).to eq({ "processing_strategy" => "vision_ai", "theme" => "light" })
    end
  end
end
