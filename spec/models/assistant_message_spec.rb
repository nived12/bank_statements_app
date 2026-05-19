# frozen_string_literal: true

require "rails_helper"

RSpec.describe AssistantMessage, type: :model do
  let(:user) { create(:user) }
  let(:conversation) { user.assistant_conversations.create!(locale: "es-MX") }

  describe "validations" do
    it "requires a known role" do
      msg = conversation.messages.build(user: user, role: "robot", content: "x")
      expect(msg).not_to be_valid
    end

    it "rejects blank content" do
      msg = conversation.messages.build(user: user, role: "user", content: "")
      expect(msg).not_to be_valid
    end

    it "rejects content over 4000 chars" do
      msg = conversation.messages.build(user: user, role: "user", content: "a" * 4_001)
      expect(msg).not_to be_valid
    end
  end

  describe "scopes" do
    it ":user_messages_billable returns only role=user" do
      conversation.messages.create!(user: user, role: "user", content: "hi")
      conversation.messages.create!(user: user, role: "assistant", content: "hi back")

      expect(described_class.user_messages_billable.count).to eq(1)
    end

    it ":for_month scopes to current month" do
      travel_to Time.zone.local(2026, 5, 15) do
        msg = conversation.messages.create!(user: user, role: "user", content: "in")
        expect(described_class.for_month.to_a).to include(msg)
      end
    end
  end
end
