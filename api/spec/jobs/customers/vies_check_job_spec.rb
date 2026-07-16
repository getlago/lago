# frozen_string_literal: true

require "rails_helper"

RSpec.describe Customers::ViesCheckJob do
  let(:customer) { create(:customer, tax_identification_number: "IE6388047V") }
  let(:vies_response) do
    {
      country_code: "FR"
    }
  end

  before do
    customer.billing_entity.update(eu_tax_management: true, country: "FR")

    allow(Customers::ApplyTaxesService).to receive(:call)
      .and_call_original
    allow_any_instance_of(Valvat).to receive(:exists?).and_return(vies_response) # rubocop:disable RSpec/AnyInstance
  end

  it_behaves_like "a unique job" do
    let(:job_args) { [customer] }
  end

  it "calls the ViesCheckService" do
    allow(Customers::ViesCheckService).to receive(:call).and_call_original

    described_class.perform_now(customer)

    expect(Customers::ViesCheckService).to have_received(:call).with(customer:)
  end

  context "when ViesCheckService returns a tax code" do
    it "applies the tax code" do
      described_class.perform_now(customer)

      expect(Customers::ApplyTaxesService).to have_received(:call)
        .with(customer: customer, tax_codes: ["lago_eu_fr_standard"])
    end

    context "when customer has pending invoices blocked by VIES" do
      let(:pending_invoice) do
        create(:invoice, :pending, customer:, organization: customer.organization, tax_status: :pending)
      end
      let(:finalized_invoice) do
        create(:invoice, :finalized, customer:, organization: customer.organization)
      end
      let(:pending_but_tax_succeeded_invoice) do
        create(:invoice, :pending, customer:, organization: customer.organization, tax_status: :succeeded)
      end

      before do
        pending_invoice
        finalized_invoice
        pending_but_tax_succeeded_invoice
      end

      it "enqueues FinalizePendingViesInvoiceJob for pending invoices with pending tax_status" do
        expect { described_class.perform_now(customer) }
          .to have_enqueued_job(Invoices::FinalizePendingViesInvoiceJob).with(pending_invoice)
      end

      it "does not enqueue job for finalized invoices" do
        expect { described_class.perform_now(customer) }
          .not_to have_enqueued_job(Invoices::FinalizePendingViesInvoiceJob).with(finalized_invoice)
      end

      it "does not enqueue job for pending invoices with succeeded tax_status" do
        expect { described_class.perform_now(customer) }
          .not_to have_enqueued_job(Invoices::FinalizePendingViesInvoiceJob).with(pending_but_tax_succeeded_invoice)
      end

      context "when customer has gated invoices blocked by VIES" do
        let(:subscription) do
          create(:subscription, :incomplete, :with_activation_rules,
            activation_rules_config: [{type: :payment, timeout_hours: 48, status: :pending}],
            customer:, organization: customer.organization)
        end
        let(:gated_invoice) do
          create(:invoice, :with_subscriptions, customer:, organization: customer.organization,
            status: :open, tax_status: :pending, subscriptions: [subscription])
        end

        before { gated_invoice }

        it "enqueues FinalizePendingViesInvoiceJob for gated invoices with pending tax_status" do
          expect { described_class.perform_now(customer) }
            .to have_enqueued_job(Invoices::FinalizePendingViesInvoiceJob).with(gated_invoice)
        end
      end
    end
  end

  context "when valvat has an error" do
    let(:pending_invoice) do
      create(:invoice, :pending, customer:, organization: customer.organization, tax_status: :pending)
    end

    before do
      pending_invoice
      allow_any_instance_of(Valvat).to receive(:exists?).and_raise(Valvat::Timeout.new("Timeout", "dummy")) # rubocop:disable RSpec/AnyInstance
    end

    it "enqueues another retry job" do
      expect { described_class.perform_now(customer) }.to have_enqueued_job(described_class)
    end

    it "does not apply taxes" do
      described_class.perform_now(customer)

      expect(Customers::ApplyTaxesService).not_to have_received(:call)
    end

    it "does not enqueue invoice finalization" do
      expect { described_class.perform_now(customer) }
        .not_to have_enqueued_job(Invoices::FinalizePendingViesInvoiceJob)
    end
  end

  # Regression guard for the uniqueness strategy. The job re-enqueues itself for
  # the same customer from inside perform (schedule_retry). With
  # `until_and_while_executing` the enqueue lock is released before perform runs,
  # so the self-reschedule is allowed. If the strategy is switched to
  # `until_executed`, the enqueue lock is still held during perform and the retry
  # is dropped, which this test detects.
  describe "self-reschedule under the real uniqueness lock" do
    let(:customer) { create(:customer, tax_identification_number: "IE6388047V") }

    around do |example|
      # Run against the real lock manager (the suite defaults to test_mode! where
      # locks are no-ops) so the enqueue lock is actually taken and released.
      ActiveJob::Uniqueness.reset_manager!
      example.run
      ActiveJob::Uniqueness.test_mode!
    end

    before do
      # Force the VIES check to fail so schedule_retry fires with a delayed retry.
      allow_any_instance_of(Valvat).to receive(:exists?).and_raise(Valvat::Timeout.new("Timeout", "dummy")) # rubocop:disable RSpec/AnyInstance
    end

    it "re-enqueues the retry for the same customer from inside perform" do
      # Running only the ViesCheckJob due now executes the initial job (releasing
      # the enqueue lock in before_perform) while leaving the delayed retry
      # enqueued. `only:` also skips the customer.vies_check webhook job the
      # service enqueues, and `at:` avoids running (and recursing on) the retry,
      # which is scheduled with a wait of at least 5 minutes.
      expect do
        perform_enqueued_jobs(only: described_class, at: Time.current) do
          described_class.perform_later(customer)
        end
      end.to have_enqueued_job(described_class).with(customer)
    end
  end
end
