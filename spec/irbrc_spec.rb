require "rails_helper"

# .irbrc is loaded by IRB, never by the app or the suite. Without this spec a
# syntax error or a renamed Rails API would go unnoticed until someone opened a
# production console and got a warning instead of a working helper.
RSpec.describe ".irbrc" do
  before(:all) { load Rails.root.join(".irbrc") }

  let(:long_description) { "SPEI ENVIADO #{"x" * 100}" }
  let(:transaction) { create(:transaction, description: long_description) }

  it "still has a reason to exist: Rails truncates strings in #inspect" do
    expect(transaction.inspect).to include("#{long_description[0, 50]}...")
    expect(transaction.inspect).not_to include(long_description)
  end

  it "still has a reason to exist: Relation#inspect stops after 10 records" do
    create_list(:transaction, 11, user: transaction.user)

    expect(transaction.user.transactions.inspect).to end_with(", ...]>")
  end

  describe "#full" do
    it "prints string attributes at full length" do
      expect { full(transaction) }.to output(/#{Regexp.escape(long_description)}/).to_stdout
    end

    it "prints every record in a relation, not just the first ten" do
      descriptions = Array.new(12) { |i| "Row number #{i}" }
      descriptions.each { |description| create(:transaction, user: transaction.user, description:) }

      expect { full(transaction.user.transactions) }
        .to output(a_string_including(*descriptions)).to_stdout
    end

    it "returns nil so IRB does not echo the records a second time" do
      expect { expect(full(transaction)).to be_nil }.to output.to_stdout
    end
  end
end
