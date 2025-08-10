# spec/factories/statement_files.rb
FactoryBot.define do
  factory :statement_file do
    user
    bank_account
    status { "pending" }
    processed_at { nil }
    parsed_json { nil }

    transient do
      attach_file { true } # allow disabling in tests
      fixture_path { Rails.root.join("spec/fixtures/files/sample.pdf") }
    end

    after(:build) do |sf, evaluator|
      next unless evaluator.attach_file
      unless sf.file.attached?
        if File.exist?(evaluator.fixture_path)
          sf.file.attach(
            io: File.open(evaluator.fixture_path),
            filename: "sample.pdf",
            content_type: "application/pdf"
          )
        else
          # Fallback: attach in-memory dummy PDF if fixture missing
          sf.file.attach(
            io: StringIO.new("%PDF-1.4\n%…\n%%EOF\n"),
            filename: "sample.pdf",
            content_type: "application/pdf"
          )
        end
      end
    end

    trait :without_file do
      attach_file { false }
    end

    trait :processed do
      status { "parsed" }
      processed_at { Time.current }
      parsed_json do
        { message: "test parsed data", transactions: [] }
      end
    end
  end
end
