# spec/support/bank_test_helper.rb
module BankTestHelper
  def self.create_test_banks
    # Create the basic banks needed for testing using find_or_create_by
    Bank.find_or_create_by(code: "bbva") do |bank|
      bank.name = "BBVA Bancomer"
      bank.supported = true
      bank.active = true
    end

    Bank.find_or_create_by(code: "santander") do |bank|
      bank.name = "Santander"
      bank.supported = true
      bank.active = true
    end

    Bank.find_or_create_by(code: "banorte") do |bank|
      bank.name = "Banorte"
      bank.supported = true
      bank.active = true
    end

    Bank.find_or_create_by(code: "banamex") do |bank|
      bank.name = "Banamex"
      bank.supported = true
      bank.active = true
    end

    Bank.find_or_create_by(code: "generic") do |bank|
      bank.name = "Otro Banco"
      bank.supported = false
      bank.active = true
    end
  end
end

RSpec.configure do |config|
  config.before(:each) do
    # Ensure banks are available for all tests
    BankTestHelper.create_test_banks

    # Set default locale for tests to avoid routing issues
    I18n.locale = :en
  end
end
