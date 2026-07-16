# frozen_string_literal: true

require "rails_helper"

RSpec.describe Emails::ResendService do
  subject(:service) { described_class.new(resource:, to:, cc:, bcc:) }

  let(:to) { nil }
  let(:cc) { nil }
  let(:bcc) { nil }
  let(:organization) { create(:organization) }
  let(:customer) { create(:customer, organization:, email: "customer@example.com") }
  let(:billing_entity) { customer.billing_entity }

  before do
    billing_entity.update!(email: "billing@example.com")
    billing_entity.email_settings = ["invoice.finalized", "credit_note.created", "payment_receipt.created"]
    billing_entity.save!
    allow(License).to receive(:premium?).and_return(true)
  end

  describe "#call" do
    context "when resource is nil" do
      let(:resource) { nil }

      it "returns a not found failure" do
        result = service.call

        expect(result).not_to be_success
        expect(result.error).to be_a(BaseService::NotFoundFailure)
        expect(result.error.resource).to eq("resource")
      end
    end

    context "with an invoice" do
      let(:resource) { create(:invoice, organization:, customer:, status:) }

      context "when invoice is finalized" do
        let(:status) { :finalized }

        it "sends the email successfully" do
          expect do
            result = service.call
            expect(result).to be_success
          end.to have_enqueued_mail(InvoiceMailer, :created)
        end

        context "with custom recipients" do
          let(:to) { ["custom@example.com", "another@example.com"] }
          let(:cc) { ["cc@example.com"] }
          let(:bcc) { ["bcc@example.com"] }

          it "sends the email with custom recipients" do
            expect do
              result = service.call
              expect(result).to be_success
            end.to have_enqueued_mail(InvoiceMailer, :created)
          end
        end
      end

      context "when invoice is draft" do
        let(:status) { :draft }

        it "returns a not allowed failure" do
          result = service.call

          expect(result).not_to be_success
          expect(result.error).to be_a(BaseService::MethodNotAllowedFailure)
          expect(result.error.code).to eq("invoice_not_finalized")
        end
      end

      context "when premium license is not available" do
        let(:status) { :finalized }

        before { allow(License).to receive(:premium?).and_return(false) }

        it "returns a forbidden failure" do
          result = service.call

          expect(result).not_to be_success
          expect(result.error).to be_a(BaseService::ForbiddenFailure)
          expect(result.error.code).to eq("premium_license_required")
        end
      end

      context "when email settings are disabled" do
        let(:status) { :finalized }

        before do
          billing_entity.email_settings = []
          billing_entity.save!
        end

        it "returns a not allowed failure" do
          result = service.call

          expect(result).not_to be_success
          expect(result.error).to be_a(BaseService::MethodNotAllowedFailure)
          expect(result.error.code).to eq("email_settings_disabled")
        end
      end

      context "when billing entity has no email" do
        let(:status) { :finalized }

        before { billing_entity.update!(email: nil) }

        it "returns a validation failure" do
          result = service.call

          expect(result).not_to be_success
          expect(result.error).to be_a(BaseService::ValidationFailure)
          expect(result.error.messages[:billing_entity]).to include("must have email configured")
        end
      end

      context "when custom recipient has invalid email format" do
        let(:status) { :finalized }
        let(:to) { ["invalid-email"] }

        it "returns a validation failure" do
          result = service.call

          expect(result).not_to be_success
          expect(result.error).to be_a(BaseService::ValidationFailure)
          expect(result.error.messages[:to]).to include("invalid email format: invalid-email")
        end
      end

      context "when customer has no email and no custom recipient" do
        let(:status) { :finalized }

        before { customer.update!(email: nil) }

        it "returns a validation failure" do
          result = service.call

          expect(result).not_to be_success
          expect(result.error).to be_a(BaseService::ValidationFailure)
          expect(result.error.messages[:to]).to include("must have at least one recipient")
        end
      end
    end

    context "with a credit note" do
      let(:invoice) { create(:invoice, organization:, customer:, status: :finalized) }
      let(:resource) { create(:credit_note, invoice:, customer:, status:) }

      context "when credit note is finalized" do
        let(:status) { :finalized }

        it "sends the email successfully" do
          expect do
            result = service.call
            expect(result).to be_success
          end.to have_enqueued_mail(CreditNoteMailer, :created)
        end
      end

      context "when credit note is draft" do
        let(:status) { :draft }

        it "returns a not allowed failure" do
          result = service.call

          expect(result).not_to be_success
          expect(result.error).to be_a(BaseService::MethodNotAllowedFailure)
          expect(result.error.code).to eq("credit_note_not_finalized")
        end
      end
    end

    context "with a payment receipt" do
      let(:invoice) { create(:invoice, organization:, customer:, status: :finalized) }
      let(:payment) { create(:payment, payable: invoice) }
      let(:resource) { create(:payment_receipt, payment:, organization:) }

      it "sends the email successfully without status check" do
        expect do
          result = service.call
          expect(result).to be_success
        end.to have_enqueued_mail(PaymentReceiptMailer, :created)
      end
    end
  end
end
