require "rails_helper"

RSpec.describe Waitlist, type: :model do
  subject { build(:waitlist) }

  describe "validations" do
    it { is_expected.to be_valid }

    it "requires email" do
      subject.email = nil
      expect(subject).not_to be_valid
      expect(subject.errors[:email]).to be_present
    end

    it "requires a valid email format" do
      subject.email = "not-an-email"
      expect(subject).not_to be_valid
    end

    it "requires unique email (case-insensitive)" do
      create(:waitlist, email: "test@example.com")
      subject.email = "TEST@example.com"
      expect(subject).not_to be_valid
      expect(subject.errors[:email]).to be_present
    end

    it "requires locale" do
      subject.locale = nil
      expect(subject).not_to be_valid
    end

    it "requires locale to be a valid locale" do
      subject.locale = "fr"
      expect(subject).not_to be_valid
    end

    it "accepts valid locales" do
      %w[es en].each do |locale|
        subject.locale = locale
        expect(subject).to be_valid
      end
    end
  end

  describe "normalizations" do
    it "downcases and strips email" do
      entry = create(:waitlist, email: "  Test@Example.COM  ")
      expect(entry.email).to eq("test@example.com")
    end
  end
end
