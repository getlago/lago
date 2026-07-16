# frozen_string_literal: true

require "rails_helper"

RSpec.describe PaymentProviders::Adyen::Webhooks::ChargebackService do
  subject(:service) { described_class.new(organization_id:, event_json:) }

  let(:organization_id) { organization.id }
  let(:organization) { create(:organization) }
  let(:membership) { create(:membership, organization:) }
  let(:customer) { create(:customer, organization:) }
  let(:payment) { create(:payment, payable: invoice, provider_payment_id: "9915555555555555") }
  let(:invoice) { create(:invoice, customer:, organization:, status:, payment_status: "succeeded") }

  describe "#call" do
    before { payment }

    context "when dispute is lost" do
      let(:event_json) do
        path = Rails.root.join("spec/fixtures/adyen/chargeback_lost_event.json")
        File.read(path)
      end

      context "when invoice is draft" do
        let(:status) { "draft" }

        it "does not updates invoice payment dispute lost" do
          expect do
            service.call
            payment.payable.reload
          end.not_to change(payment.payable.reload, :payment_dispute_lost_at).from(nil)
        end

        it "does not deliver webhook" do
          expect { service.call }.not_to have_enqueued_job(SendWebhookJob)
        end
      end

      context "when invoice is finalized" do
        let(:status) { "finalized" }

        it "updates invoice payment dispute lost" do
          expect do
            service.call
            payment.payable.reload
          end.to change(payment.payable, :payment_dispute_lost_at).from(nil)
        end

        it "delivers a webhook" do
          expect do
            service.call
            payment.payable.reload
          end.to have_enqueued_job(SendWebhookJob).with(
            "invoice.payment_dispute_lost",
            payment.payable,
            provider_error: "Merchandise/Services Not Received"
          )
        end
      end
    end

    context "when dispute is won" do
      let(:event_json) do
        path = Rails.root.join("spec/fixtures/adyen/chargeback_won_event.json")
        File.read(path)
      end

      context "when invoice is draft" do
        let(:status) { "draft" }

        it "does not updates invoice payment dispute lost" do
          expect do
            service.call
            payment.payable.reload
          end.not_to change(payment.payable.reload, :payment_dispute_lost_at).from(nil)
        end

        it "does not deliver webhook" do
          expect { service.call }.not_to have_enqueued_job(SendWebhookJob)
        end
      end

      context "when invoice is finalized" do
        let(:status) { "finalized" }

        it "does not updates invoice payment dispute lost" do
          expect do
            service.call
            payment.payable.reload
          end.not_to change(payment.payable.reload, :payment_dispute_lost_at).from(nil)
        end

        it "does not deliver webhook" do
          expect { service.call }.not_to have_enqueued_job(SendWebhookJob)
        end
      end
    end
  end
end
