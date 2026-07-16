# frozen_string_literal: true

require "rails_helper"

# rubocop:disable RSpec/AnyInstance
RSpec.describe SendEmailJob do
  subject(:perform_job) { job.perform_now }

  let(:job) { described_class.new("InvoiceMailer", "created", "deliver_now", args: [], params:) }
  let(:invoice) { create(:invoice, fees_amount_cents: 100) }
  let(:params) { {invoice:} }
  let(:error) { Net::SMTPServerBusy.new("busy") }

  before do
    allow(Utils::EmailActivityLog).to receive(:produce)
    allow_any_instance_of(InvoiceMailer).to receive(:ensure_pdf) # rubocop:disable RSpec/AnyInstance
  end

  it "delivers email" do
    expect { perform_job }.to change { ActionMailer::Base.deliveries.count }.by(1)
  end

  it "logs activity" do
    perform_job

    expect(Utils::EmailActivityLog).to have_received(:produce).with(
      document: invoice,
      message: be_present,
      error: nil
    )
  end

  context "with user_id" do
    let(:params) { {invoice:, resend: true, user_id: "user-123"} }

    it "passes user_id to activity log" do
      perform_job

      expect(Utils::EmailActivityLog).to have_received(:produce).with(
        document: invoice,
        message: be_present,
        error: nil,
        resend: true,
        user_id: "user-123"
      )
    end
  end

  context "with api_key_id" do
    let(:params) { {invoice:, api_key_id: "key-456"} }

    it "passes api_key_id to activity log" do
      perform_job

      expect(Utils::EmailActivityLog).to have_received(:produce).with(
        document: invoice,
        message: be_present,
        error: nil,
        api_key_id: "key-456"
      )
    end
  end

  context "when email is not sent" do
    let(:invoice) { create(:invoice, fees_amount_cents: 0) }

    it "does not deliver email" do
      expect { perform_job }.not_to change { ActionMailer::Base.deliveries.count }
    end

    it "does not log activity" do
      perform_job

      expect(Utils::EmailActivityLog).not_to have_received(:produce)
    end
  end

  describe "retry configuration" do
    it "retries on PaymentReceipts::FilesNotReadyError" do
      matcher = described_class.rescue_handlers.find { |klass, _| klass == "PaymentReceipts::FilesNotReadyError" }
      expect(matcher).not_to be_nil
    end
  end

  context "when delivery fails with retryable error" do
    before { allow_any_instance_of(Mail::Message).to receive(:deliver).and_raise(error) }

    it "does not log activity on first attempt" do
      perform_job
      expect(Utils::EmailActivityLog).not_to have_received(:produce)
    end

    context "when retries exhausted" do
      before { job.exception_executions["[Net::SMTPServerBusy]"] = 25 }

      it "logs activity with error after final failure" do
        expect { perform_job }.to raise_error(Net::SMTPServerBusy)

        expect(Utils::EmailActivityLog).to have_received(:produce).with(
          document: invoice,
          message: be_present,
          error:
        )
      end
    end
  end

  context "with retryable errors" do
    [
      [ActiveJob::DeserializationError.allocate, 6],
      [LagoHttpClient::HttpError.new(500, "error", "https://example.com"), 6],
      [Net::ReadTimeout, 6],
      [Net::OpenTimeout, 6],
      [EOFError, 6],
      [Net::SMTPServerBusy.new("busy"), 25],
      [PaymentReceipts::FilesNotReadyError, 8]
    ].each do |error, attempts|
      error_class = error.is_a?(Class) ? error : error.class

      context "when a #{error_class.name} error is raised" do
        before do
          allow_any_instance_of(ActionMailer::Parameterized::Mailer).to receive(:public_send).and_raise(error) # rubocop:disable RSpec/AnyInstance
        end

        it "raises a #{error_class.name} error and retries" do
          assert_performed_jobs(attempts, only: [described_class]) do
            expect do
              described_class.perform_later("InvoiceMailer", "created", "deliver_now", args: [], params:)
            end.to raise_error(error_class)
          end
        end
      end
    end
  end
end
# rubocop:enable RSpec/AnyInstance
