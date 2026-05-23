# frozen_string_literal: true

require "rails_helper"

RSpec.describe AssistantConversation, type: :model do
  let(:user) { create(:user) }

  describe "associations" do
    it "belongs to user" do
      conv = described_class.new(user: user, locale: "es-MX")
      expect(conv).to be_valid
    end

    it "has many messages" do
      conv = user.assistant_conversations.create!(locale: "es-MX")
      conv.messages.create!(user: user, role: "user", content: "hi")
      conv.messages.create!(user: user, role: "assistant", content: "hello")

      expect(conv.messages.count).to eq(2)
    end

    it "destroys messages when conversation is destroyed" do
      conv = user.assistant_conversations.create!(locale: "es-MX")
      conv.messages.create!(user: user, role: "user", content: "hi")

      expect { conv.destroy }.to change(AssistantMessage, :count).by(-1)
    end
  end

  describe "validations" do
    it "requires a valid locale" do
      conv = user.assistant_conversations.build(locale: "fr-FR")
      expect(conv).not_to be_valid
    end

    it "accepts es-MX" do
      conv = user.assistant_conversations.build(locale: "es-MX")
      expect(conv).to be_valid
    end

    it "accepts en" do
      conv = user.assistant_conversations.build(locale: "en")
      expect(conv).to be_valid
    end

    it "limits title length to 120" do
      conv = user.assistant_conversations.build(locale: "es-MX", title: "a" * 121)
      expect(conv).not_to be_valid
    end
  end

  describe ".recent" do
    it "orders by last_message_at desc" do
      older = user.assistant_conversations.create!(locale: "es-MX", last_message_at: 2.days.ago)
      newer = user.assistant_conversations.create!(locale: "es-MX", last_message_at: 1.hour.ago)

      expect(described_class.recent).to eq([newer, older])
    end
  end

  describe "#touch_last_message!" do
    it "updates last_message_at and message_count" do
      conv = user.assistant_conversations.create!(locale: "es-MX")
      conv.messages.create!(user: user, role: "user", content: "hi")
      conv.messages.create!(user: user, role: "assistant", content: "hello")

      conv.touch_last_message!

      expect(conv.reload.message_count).to eq(2)
      expect(conv.last_message_at).to be_present
    end
  end
end
