# frozen_string_literal: true

require "rails_helper"

RSpec.describe AssistantHelper, type: :helper do
  describe "#recency_bucket" do
    let(:now) { Time.zone.local(2026, 5, 19, 15, 0, 0) }

    around do |example|
      travel_to(now) { example.run }
    end

    it "returns :today for a time earlier today" do
      expect(helper.recency_bucket(now - 6.hours)).to eq(:today)
    end

    it "returns :today for the very start of today" do
      expect(helper.recency_bucket(now.beginning_of_day + 1.minute)).to eq(:today)
    end

    it "returns :yesterday for a time within the prior calendar day" do
      expect(helper.recency_bucket(now - 1.day)).to eq(:yesterday)
    end

    it "returns :this_week for a time 3 days ago" do
      expect(helper.recency_bucket(now - 3.days)).to eq(:this_week)
    end

    it "returns :this_week for a time 6 days ago" do
      expect(helper.recency_bucket(now - 6.days)).to eq(:this_week)
    end

    it "returns :earlier for a time 7+ days ago" do
      expect(helper.recency_bucket(now - 7.days)).to eq(:earlier)
    end

    it "returns :earlier for nil" do
      expect(helper.recency_bucket(nil)).to eq(:earlier)
    end
  end

  describe "#render_assistant_markdown" do
    it "renders bold" do
      expect(helper.render_assistant_markdown("Hola **Uber**"))
        .to eq("<p>Hola <strong>Uber</strong></p>")
    end

    it "renders bullet lists" do
      html = helper.render_assistant_markdown("- **Uber** — $100\n- **CFE** — $200")
      expect(html).to eq("<ul><li><strong>Uber</strong> — $100</li><li><strong>CFE</strong> — $200</li></ul>")
    end

    it "separates paragraphs from lists" do
      html = helper.render_assistant_markdown("Detecté **9 pagos**:\n- **Uber** — $100\n- **CFE** — $200")
      expect(html).to include("<p>Detecté <strong>9 pagos</strong>:</p>")
      expect(html).to include("<ul><li><strong>Uber</strong>")
    end

    it "escapes raw HTML" do
      expect(helper.render_assistant_markdown("<script>x</script>"))
        .to eq("<p>&lt;script&gt;x&lt;/script&gt;</p>")
    end

    it "returns empty string for blank input" do
      expect(helper.render_assistant_markdown(nil)).to eq("")
      expect(helper.render_assistant_markdown("")).to eq("")
    end
  end
end
