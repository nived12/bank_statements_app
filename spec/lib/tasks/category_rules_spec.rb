# frozen_string_literal: true

require "rails_helper"
require "rake"

# The task runs by hand against production data, over every user with rules. The
# properties that matter: preview writes nothing, APPLY writes, and a user whose
# rules already agree with their transactions produces no output at all.
RSpec.describe "category_rules rake tasks", type: :task do
  before(:all) do
    Rake::Task.clear
    Rails.application.load_tasks
  end

  before { Rake::Task[task_name].reenable }

  # Rake reports to stdout; capture it so the suite output stays clean and examples
  # can assert on what the operator is actually told.
  def capture_stdout
    original = $stdout
    $stdout = StringIO.new
    yield
    $stdout.string
  ensure
    $stdout = original
  end

  def run
    capture_stdout { Rake::Task[task_name].invoke }
  end

  let(:task_name) { "category_rules:backfill" }

  let(:user) { create(:user) }
  let(:bank_account) { create(:bank_account, user: user) }
  let(:statement_file) { create(:statement_file, user: user, bank_account: bank_account) }
  let(:parent_category) { create(:category, user: user, name: "Deudas y Prestamos") }
  let(:rule_category) do
    create(:category, user: user, name: "Credito Automotriz", parent: parent_category)
  end
  let(:wrong_category) { create(:category, user: user, name: "Prestamos Personales") }

  let!(:rule) do
    create(
      :category_rule, user: user, category: rule_category,
      pattern: "pago de prestamo total de recibo", match_type: "contains"
    )
  end

  let!(:transaction) do
    create(
      :transaction,
      user: user, bank_account: bank_account, statement_file: statement_file,
      description: "PAGO DE PRESTAMO 9837815631 TOTAL DE RECIBO",
      category: wrong_category, source: :statement_file
    )
  end

  around do |example|
    original = ENV["APPLY"]
    ENV["USER_ID"] = user.id.to_s
    example.run
    ENV["APPLY"] = original
    ENV.delete("USER_ID")
  end

  context "without APPLY" do
    before { ENV.delete("APPLY") }

    it "reports the change it would make" do
      output = run

      expect(output).to include("PAGO DE PRESTAMO 9837815631 TOTAL DE RECIBO")
      expect(output).to include("Prestamos Personales", "Credito Automotriz")
    end

    it "says nothing was written" do
      expect(run).to include("Preview only")
    end

    it "leaves the transaction alone" do
      run

      expect(transaction.reload.category_id).to eq(wrong_category.id)
    end
  end

  context "with APPLY=1" do
    before { ENV["APPLY"] = "1" }

    it "moves the transaction to the rule's category" do
      run

      expect(transaction.reload.category_id).to eq(rule_category.id)
    end

    it "says it applied" do
      expect(run).to include("Applied.")
    end
  end

  context "when a transaction has no category to move away from" do
    before do
      ENV.delete("APPLY")
      transaction.update!(category: nil)
    end

    it "names the empty category rather than blowing up on nil" do
      expect(run).to include("sin categoría")
    end
  end

  context "when every transaction already matches its rule" do
    before do
      ENV.delete("APPLY")
      transaction.update!(category: rule_category)
    end

    it "prints no per-user section" do
      expect(run).not_to include(user.email)
    end
  end
end
