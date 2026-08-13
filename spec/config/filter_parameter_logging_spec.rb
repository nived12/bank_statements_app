require "rails_helper"

# The log filter and #inspect read the same config, pulling in opposite
# directions: logs should be paranoid, a production console should be readable.
# Both directions are asserted here because silently drifting either way is
# invisible until it matters -- a leak in the logs, or a console full of
# [FILTERED] when you are trying to debug a transaction.
RSpec.describe "parameter filtering" do
  describe "logs" do
    let(:filter) { ActiveSupport::ParameterFilter.new(Rails.application.config.filter_parameters) }

    # The list was written as %i[:passw, :email], which builds :":passw," and
    # matches nothing. Guarding the intent, not the syntax.
    it "filters personal and financial params" do
      filtered = filter.filter(
        "email" => "someone@example.com",
        "amount" => 1234.56,
        "description" => "SPEI ENVIADO",
        "password" => "hunter2",
        "parsed_json" => "{}"
      )

      expect(filtered.values).to all(eq("[FILTERED]"))
    end

    it "leaves non-sensitive params alone" do
      filtered = filter.filter("id" => 7, "transaction_type" => "income", "page" => 2)

      expect(filtered).to eq("id" => 7, "transaction_type" => "income", "page" => 2)
    end
  end

  describe "#inspect" do
    it "keeps secrets hidden" do
      user = build(:user)

      expect(user.inspect).to include("password_digest: [FILTERED]")
    end

    it "hides passwords and nothing else at the base level" do
      expect(ActiveRecord::Base.filter_attributes).to eq(%i[passw])
    end

    # Models calling `encrypts` snapshot filter_attributes at load time, which
    # under eager loading happens before the console list is applied. If the
    # rebuild in the initializer regresses, these columns print in the clear.
    it "keeps encrypted columns hidden even on models that loaded early" do
      expect(StatementFile.filter_attributes)
        .to include(:parsed_json, :error_message, :redaction_map, :file_password)
    end

    it "leaves the domain columns readable, which is the point of the console" do
      transaction = build(:transaction, description: "SPEI ENVIADO", merchant: "ipark", amount: -2000)

      expect(transaction.inspect).to include("SPEI ENVIADO", "ipark", "-0.2e4")
    end

    it "leaves contact columns readable" do
      user = build(:user, email: "someone@example.com")

      expect(user.inspect).to include("someone@example.com")
    end
  end
end
