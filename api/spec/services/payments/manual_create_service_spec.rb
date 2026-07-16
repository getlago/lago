# frozen_string_literal: true

require "rails_helper"

RSpec.describe Payments::ManualCreateService do
  subject(:service) { described_class.new(organization:, params:) }

  let(:invoice) { create(:invoice, customer:, organization:, total_amount_cents: 10000, status: :finalized) }
  let(:invoice_id) { invoice.id }
  let(:organization) { create(:organization) }
  let(:customer) { create(:customer, organization:) }
  let(:params) { {invoice_id:, amount_cents:, reference: "ref1", paid_at:} }
  let(:paid_at) { 1.year.ago.iso8601 }
  let(:amount_cents) { 10000 }

  describe "#call" do
    context "when organization is not premium" do
      it "returns forbidden failure" do
        result = service.call

        expect(result).not_to be_success
        expect(result.error).to be_a(BaseService::ForbiddenFailure)
      end
    end

    context "when organization is premium", :premium do
      context "when invoice does not exist" do
        let(:invoice_id) { SecureRandom.uuid }

        it "returns not found failure" do
          result = service.call

          expect(result).not_to be_success
          expect(result.error).to be_a(BaseService::NotFoundFailure)
        end
      end

      context "when invoice is in status that does not allow manual payment" do
        let(:invoice) { create(:invoice, :draft, customer:, organization:) }

        it "returns forbidden failure" do
          result = service.call

          expect(result).not_to be_success
          expect(result.error).to be_a(BaseService::ForbiddenFailure)
        end
      end

      context "when invoice's payment request is succeeded" do
        let(:payment_request) { create(:payment_request, payment_status: "succeeded") }

        before do
          create(:payment_request_applied_invoice, invoice:, payment_request:)
        end

        it "returns validation failure" do
          result = service.call

          expect(result).not_to be_success
          expect(result.error).to be_a(BaseService::ValidationFailure)
        end
      end

      context "when payment amount cents is greater than invoice's remaining amount cents" do
        let(:amount_cents) { 10001 }

        it "returns validation failure" do
          result = service.call

          expect(result).not_to be_success
          expect(result.error).to be_a(BaseService::ValidationFailure)
        end
      end

      context "when amount_cents in missing" do
        let(:params) { {invoice_id:, amount_in_cents: 123, reference: "ref1", paid_at:} }

        it "returns a validation failure" do
          result = service.call

          expect(result).not_to be_success
          expect(result.error).to be_a(BaseService::ValidationFailure)
          expect(result.error.messages[:amount_cents]).to eq(["invalid_value"])
        end
      end

      context "when reference in missing" do
        let(:params) { {invoice_id:, amount_cents: 123, paid_at:} }

        it "returns a validation failure" do
          result = service.call

          expect(result).not_to be_success
          expect(result.error).to be_a(BaseService::ValidationFailure)
          expect(result.error.messages[:reference]).to eq(["value_is_mandatory"])
        end
      end

      context "when invoice_id in missing" do
        let(:params) { {amount_cents: 123, paid_at:} }

        it "returns a validation failure" do
          result = service.call

          expect(result).not_to be_success
          expect(result.error).to be_a(BaseService::ValidationFailure)
          expect(result.error.messages[:invoice_id]).to eq(["value_is_mandatory"])
        end
      end

      context "when paid_at format is invalid" do
        let(:paid_at) { "invalid_date" }

        it "returns a validation failure" do
          result = service.call

          expect(result).not_to be_success
          expect(result.error).to be_a(BaseService::ValidationFailure)
          expect(result.error.messages[:paid_at]).to eq(["invalid_date"])
        end
      end

      context "when paid_at format is valid but different format" do
        let(:paid_at) { "2024-01-20" }

        it "creates a payment with valid date" do
          result = service.call

          expect(result).to be_success
          expect(result.payment.payment_type).to eq("manual")
          expect(result.payment.created_at).to eq(paid_at)
        end
      end

      context "when payment amount cents is smaller than invoice remaining amount cents" do
        let(:amount_cents) { 2000 }

        it "creates a payment" do
          result = service.call

          expect(result).to be_success
          expect(result.payment.payment_type).to eq("manual")
          expect(result.payment.created_at).to eq(paid_at)
        end

        it "updates invoice's total paid amount cents" do
          result = service.call
          expect(result.payment.payable.total_paid_amount_cents).to eq(amount_cents)
        end

        context "when issue_receipts_enabled is true" do
          before { organization.update!(premium_integrations: %w[issue_receipts]) }

          it "enqueues a payment receipt job" do
            expect { service.call }.to have_enqueued_job(PaymentReceipts::CreateJob)
          end
        end

        context "when there is an integration customer" do
          let(:integration) do
            create(
              :netsuite_integration,
              organization:,
              settings: {
                account_id: "acc_12345",
                client_id: "cli_12345",
                script_endpoint_url: Faker::Internet.url,
                sync_payments: true
              }
            )
          end

          before { create(:netsuite_customer, integration:, customer:) }

          it "enqueues an aggregator payment job" do
            expect { service.call }.to have_enqueued_job(Integrations::Aggregator::Payments::CreateJob)
          end
        end
      end

      context "when payment amount cents is equal to invoice remaining amount cents" do
        let(:amount_cents) { 10000 }

        it "creates a payment" do
          result = service.call

          expect(result).to be_success
          expect(result.payment.payment_type).to eq("manual")
        end

        it "updates invoice's total paid amount cents" do
          result = service.call

          expect(result.payment.payable.total_paid_amount_cents).to eq(amount_cents)
        end

        it "updates invoice's payment status to suceeded" do
          result = service.call

          expect(result.payment.payable.payment_status).to eq("succeeded")
          expect(SendWebhookJob).to have_been_enqueued.with(
            "invoice.payment_status_updated",
            invoice
          )
        end

        it "produces an activity log" do
          payment = described_class.call(organization:, params:).payment

          expect(Utils::ActivityLog).to have_produced("payment.recorded").after_commit.with(payment)
        end

        context "when issue_receipts_enabled is true" do
          before { organization.update!(premium_integrations: %w[issue_receipts]) }

          it "enqueues a payment receipt job" do
            expect { service.call }.to have_enqueued_job(PaymentReceipts::CreateJob)
          end
        end
      end

      context "when invoice has offset amounts from credit notes" do
        let(:invoice) { create(:invoice, customer:, organization:, total_amount_cents: 10000, status: :finalized) }
        let(:credit_note) do
          create(
            :credit_note,
            invoice:,
            customer:,
            offset_amount_cents: 3000,
            credit_amount_cents: 0,
            refund_amount_cents: 0,
            total_amount_cents: 3000,
            status: :finalized
          )
        end
        let(:invoice_settlement) do
          create(
            :invoice_settlement,
            target_invoice: invoice,
            source_credit_note: credit_note,
            settlement_type: :credit_note,
            amount_cents: 3000,
            organization:
          )
        end

        before { invoice_settlement }

        context "when payment covers remaining amount after offset" do
          let(:amount_cents) { 7000 } # 10000 total - 3000 offset = 7000 remaining

          it "marks invoice as paid" do
            result = service.call

            expect(result).to be_success
            expect(result.payment.payable.payment_status).to eq("succeeded")
          end

          it "updates total_paid_amount_cents correctly" do
            result = service.call

            expect(result.payment.payable.total_paid_amount_cents).to eq(7000)
          end

          it "sends payment status updated webhook" do
            service.call

            expect(SendWebhookJob).to have_been_enqueued.with(
              "invoice.payment_status_updated",
              invoice
            )
          end
        end

        context "when payment is less than remaining amount after offset" do
          let(:amount_cents) { 5000 }

          it "does not mark invoice as paid" do
            result = service.call

            expect(result).to be_success
            expect(result.payment.payable.payment_status).not_to eq("succeeded")
          end

          it "updates total_paid_amount_cents correctly" do
            result = service.call

            expect(result.payment.payable.total_paid_amount_cents).to eq(5000)
          end
        end
      end

      context "when invoice has partial payment and offset" do
        let(:invoice) do
          create(
            :invoice,
            customer:,
            organization:,
            total_amount_cents: 10000,
            total_paid_amount_cents: 3000,
            status: :finalized
          )
        end
        let(:credit_note) do
          create(
            :credit_note,
            invoice:,
            customer:,
            offset_amount_cents: 2000,
            status: :finalized
          )
        end

        before do
          create(
            :payment,
            payable: invoice,
            organization:,
            customer:,
            amount_cents: 3000,
            status: "succeeded",
            payable_payment_status: "succeeded"
          )

          create(
            :invoice_settlement,
            target_invoice: invoice,
            source_credit_note: credit_note,
            settlement_type: :credit_note,
            amount_cents: 2000,
            organization:
          )
        end

        context "when final payment covers remaining" do
          let(:amount_cents) { 5000 } # 10000 - 3000 paid - 2000 offset = 5000

          it "marks invoice as paid" do
            result = service.call

            expect(result).to be_success
            expect(result.payment.payable.payment_status).to eq("succeeded")
            expect(result.payment.payable.total_paid_amount_cents).to eq(8000) # 3000 + 5000
          end
        end
      end
    end
  end
end
