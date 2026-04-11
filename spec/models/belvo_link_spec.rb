require "rails_helper"

RSpec.describe BelvoLink, type: :model do
  describe "associations" do
    it "belongs to user" do
      link = build(:belvo_link)
      expect(link.user).to be_present
    end

    it "belongs to bank optionally" do
      link = build(:belvo_link, bank: nil, user: create(:user))
      expect(link).to be_valid
    end
  end

  describe "validations" do
    it "requires belvo_link_id" do
      link = build(:belvo_link, belvo_link_id: nil)
      expect(link).not_to be_valid
    end

    it "requires belvo_institution" do
      link = build(:belvo_link, belvo_institution: nil)
      expect(link).not_to be_valid
    end

    it "requires unique belvo_link_id" do
      create(:belvo_link, belvo_link_id: "abc-123")
      duplicate = build(:belvo_link, belvo_link_id: "abc-123")
      expect(duplicate).not_to be_valid
    end
  end

  describe "enums" do
    it "defines status enum" do
      expect(described_class.statuses).to include(
        "active" => "active",
        "inactive" => "inactive",
        "login_error" => "login_error",
        "token_required" => "token_required"
      )
    end

    it "defines sync_status enum" do
      expect(described_class.sync_statuses).to include(
        "pending" => "pending",
        "syncing" => "syncing",
        "synced" => "synced",
        "error" => "error"
      )
    end
  end

  describe "encryption" do
    it "encrypts belvo_link_id" do
      link = create(:belvo_link)
      expect(link.encrypted_attribute?(:belvo_link_id)).to be true
    end
  end

  describe "link limit validation" do
    let(:user) { create(:user) }

    it "allows up to 3 active links" do
      create(:belvo_link, user: user, belvo_institution: "bank_a")
      create(:belvo_link, user: user, belvo_institution: "bank_b")
      third_link = build(:belvo_link, user: user, belvo_institution: "bank_c")
      expect(third_link).to be_valid
    end

    it "rejects a 4th active link" do
      create(:belvo_link, user: user, belvo_institution: "bank_a")
      create(:belvo_link, user: user, belvo_institution: "bank_b")
      create(:belvo_link, user: user, belvo_institution: "bank_c")
      fourth_link = build(:belvo_link, user: user, belvo_institution: "bank_d")
      expect(fourth_link).not_to be_valid
      expect(fourth_link.errors.added?(:base, :link_limit_reached)).to be true
    end

    it "does not count inactive links toward the limit" do
      create(:belvo_link, user: user, belvo_institution: "bank_a", status: :inactive)
      create(:belvo_link, user: user, belvo_institution: "bank_b", status: :inactive)
      create(:belvo_link, user: user, belvo_institution: "bank_c", status: :inactive)
      new_link = build(:belvo_link, user: user, belvo_institution: "bank_d")
      expect(new_link).to be_valid
    end
  end

  describe "scopes" do
    it ".needing_reauth returns links with login_error or token_required" do
      active_link = create(:belvo_link, status: :active, belvo_institution: "bank_a")
      reauth_link = create(:belvo_link, :needs_reauth, belvo_institution: "bank_b")
      error_link = create(:belvo_link, status: :login_error, belvo_institution: "bank_c")

      result = described_class.needing_reauth
      expect(result).to include(reauth_link, error_link)
      expect(result).not_to include(active_link)
    end
  end
end
