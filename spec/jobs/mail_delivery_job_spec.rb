require "rails_helper"

RSpec.describe MailDeliveryJob do
  let(:user) { create(:user) }
  let(:message) { instance_double(ActionMailer::MessageDelivery) }
  let(:rate_limit) { Resend::Error::RateLimitExceededError.new("Too many requests", 429, {}) }

  before do
    allow(ApplicationMailer).to receive(:confirmation_email).and_return(message)
    allow(Sentry).to receive(:capture_message)
    allow(Rails.logger).to receive(:error)
  end

  def deliver
    described_class.perform_now("ApplicationMailer", "confirmation_email", "deliver_now", args: [user])
  end

  describe "rate limiting" do
    before { allow(message).to receive(:deliver_now).and_raise(rate_limit) }

    it "re-enqueues itself when Resend rate-limits the send" do
      expect { deliver }.to change { enqueued_jobs.size }.by(1)
    end

    it "does not record a delivery it never made" do
      deliver

      expect(ActionMailer::Base.deliveries).to be_empty
    end

    it "reports to Sentry and stops after the attempt budget" do
      perform_enqueued_jobs { deliver }

      expect(message).to have_received(:deliver_now).exactly(described_class::RATE_LIMIT_ATTEMPTS).times
      expect(Sentry).to have_received(:capture_message)
        .with(/gave up on ApplicationMailer#confirmation_email/, level: :error)
      expect(enqueued_jobs).to be_empty
    end
  end

  # RateLimitExceededError < ServerError < Resend::Error, so widening the rescue
  # to Resend::Error would silently retry 422s forever.
  it "lets an unrelated Resend failure raise through" do
    allow(message).to receive(:deliver_now).and_raise(Resend::Error::InvalidRequestError.new("bad", 422, {}))

    expect { deliver }.to raise_error(Resend::Error::InvalidRequestError)
    expect(enqueued_jobs).to be_empty
  end

  # Without this, deleting the delivery_job line in application.rb leaves every
  # other example in this file green.
  it "is the delivery job ActionMailer actually uses" do
    expect(ActionMailer::Base.delivery_job).to eq(described_class)
  end
end
