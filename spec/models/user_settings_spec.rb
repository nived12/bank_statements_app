# frozen_string_literal: true

require "rails_helper"

RSpec.describe UserSetting, type: :model do
  describe "associations" do
    it "belongs to user" do
      settings = build(:user_setting)
      expect(settings.user).to be_present
    end
  end

  describe "validations" do
    it "validates uniqueness of user_id" do
      user = create(:user)
      # User already has user_settings from after_create callback
      duplicate = build(:user_setting, user: user)
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:user_id]).to be_present
    end

    context "preferences validation" do
      let(:user) { create(:user) }

      it "allows valid preference keys" do
        # Update existing user_settings instead of creating new one
        user.user_setting.update(preferences: { "processing_strategy" => "text_with_ai" })
        expect(user.user_setting.reload).to be_valid
      end

      it "rejects invalid preference keys" do
        user.user_setting.preferences = { "invalid_key" => "value" }
        expect(user.user_setting).not_to be_valid
        expect(user.user_setting.errors[:preferences]).to include("contains invalid keys: invalid_key")
      end

      it "allows empty preferences" do
        user.user_setting.update(preferences: {})
        expect(user.user_setting.reload).to be_valid
      end
    end
  end

  describe "#processing_strategy" do
    let(:user) { create(:user) }

    it "returns the processing_strategy from preferences" do
      user.user_setting.update(preferences: { "processing_strategy" => "vision_ai" })
      expect(user.user_setting.processing_strategy).to eq("vision_ai")
    end

    it "returns vision_ai as default when not set" do
      user.user_setting.update(preferences: {})
      expect(user.user_setting.processing_strategy).to eq("vision_ai")
    end
  end

  describe "#processing_strategy=" do
    let(:user) { create(:user) }

    it "sets the processing_strategy in preferences" do
      user.user_setting.processing_strategy = "text_with_ai"
      expect(user.user_setting.preferences["processing_strategy"]).to eq("text_with_ai")
    end

    it "preserves other preferences" do
      user.user_setting.preferences = {}
      user.user_setting.processing_strategy = "vision_ai"
      expect(user.user_setting.preferences).to eq({ "processing_strategy" => "vision_ai" })
    end
  end

  describe "notification preference accessors" do
    let(:settings) { create(:user).user_setting }

    %w[notify_statement_imports notify_goal_milestones notify_debt_reminders].each do |pref|
      describe "##{pref}" do
        it "returns true by default" do
          settings.update!(preferences: {})
          expect(settings.public_send(pref)).to be(true)
        end

        it "returns false when set to false" do
          settings.update!(preferences: { pref => false })
          expect(settings.public_send(pref)).to be(false)
        end
      end

      describe "##{pref}=" do
        it "persists the value in preferences without overwriting other keys" do
          settings.update!(preferences: { "processing_strategy" => "vision_ai" })
          settings.public_send(:"#{pref}=", false)
          expect(settings.preferences["processing_strategy"]).to eq("vision_ai")
          expect(settings.preferences[pref]).to be(false)
        end
      end
    end

    it "allows all notification preference keys to be set together" do
      settings.preferences = {
        "notify_statement_imports" => false,
        "notify_goal_milestones" => false,
        "notify_debt_reminders" => false
      }
      expect(settings).to be_valid
    end
  end
end
