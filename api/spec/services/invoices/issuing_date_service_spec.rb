# frozen_string_literal: true

require "rails_helper"

RSpec.describe Invoices::IssuingDateService do
  subject(:issuing_date_service) { described_class.new(customer_settings: customer, recurring:) }

  let(:customer) do
    build(
      :customer,
      subscription_invoice_issuing_date_anchor:,
      subscription_invoice_issuing_date_adjustment:,
      invoice_grace_period:
    )
  end

  let(:subscription_invoice_issuing_date_anchor) { "current_period_end" }
  let(:subscription_invoice_issuing_date_adjustment) { "keep_anchor" }
  let(:invoice_grace_period) { 3 }

  describe "#issuing_date_adjustment" do
    let(:recurring) { true }

    context "with current_period_end + keep_anchor" do
      let(:subscription_invoice_issuing_date_anchor) { "current_period_end" }
      let(:subscription_invoice_issuing_date_adjustment) { "keep_anchor" }

      it "returns -1" do
        expect(issuing_date_service.issuing_date_adjustment).to eq(-1)
      end
    end

    context "with current_period_end + align_with_finalization_date" do
      context "when invoice_grace_period > 0" do
        let(:subscription_invoice_issuing_date_anchor) { "current_period_end" }
        let(:subscription_invoice_issuing_date_adjustment) { "align_with_finalization_date" }

        it "returns invoice_grace_period" do
          expect(issuing_date_service.issuing_date_adjustment).to eq(3)
        end
      end

      context "when invoice_grace_period is 0" do
        let(:subscription_invoice_issuing_date_anchor) { "current_period_end" }
        let(:subscription_invoice_issuing_date_adjustment) { "align_with_finalization_date" }
        let(:invoice_grace_period) { 0 }

        it "returns -1" do
          expect(issuing_date_service.issuing_date_adjustment).to eq(-1)
        end
      end
    end

    context "with next_period_start + keep_anchor" do
      let(:subscription_invoice_issuing_date_anchor) { "next_period_start" }
      let(:subscription_invoice_issuing_date_adjustment) { "keep_anchor" }

      it "returns 0" do
        expect(issuing_date_service.issuing_date_adjustment).to eq(0)
      end
    end

    context "with next_period_start + align_with_finalization_date" do
      let(:subscription_invoice_issuing_date_anchor) { "next_period_start" }
      let(:subscription_invoice_issuing_date_adjustment) { "align_with_finalization_date" }

      it "returns grace_period" do
        expect(issuing_date_service.issuing_date_adjustment).to eq(3)
      end
    end

    context "with no preferences set on the customer level" do
      let(:billing_entity) do
        build(
          :billing_entity,
          subscription_invoice_issuing_date_anchor: "current_period_end",
          subscription_invoice_issuing_date_adjustment: "keep_anchor",
          invoice_grace_period: 3
        )
      end

      let(:customer) { build(:customer, billing_entity:) }

      it "returns value based on billing entity settings" do
        expect(issuing_date_service.issuing_date_adjustment).to eq(-1)
      end
    end

    context "when recurring = false" do
      let(:recurring) { false }

      it "returns invoice_grace_period" do
        expect(issuing_date_service.issuing_date_adjustment).to eq(3)
      end
    end

    context "with customer as a hash" do
      subject(:issuing_date_service) do
        described_class.new(
          customer_settings: {
            subscription_invoice_issuing_date_anchor: "current_period_end",
            subscription_invoice_issuing_date_adjustment: "keep_anchor",
            invoice_grace_period: 3
          },
          billing_entity_settings: customer.billing_entity,
          recurring:
        )
      end

      it "returns value based on customer hash" do
        expect(issuing_date_service.issuing_date_adjustment).to eq(-1)
      end
    end

    context "with billing_entity as a hash" do
      subject(:issuing_date_service) do
        described_class.new(
          customer_settings: customer,
          billing_entity_settings: {
            subscription_invoice_issuing_date_anchor: "current_period_end",
            subscription_invoice_issuing_date_adjustment: "keep_anchor",
            invoice_grace_period: 3
          },
          recurring:
        )
      end

      it "returns value based on billing entity hash" do
        expect(issuing_date_service.issuing_date_adjustment).to eq(-1)
      end
    end
  end

  describe "#grace_period" do
    let(:recurring) { true }

    context "with preferences set on the customer level" do
      let(:invoice_grace_period) { 3 }

      it "returns value based on billing entity settings" do
        expect(issuing_date_service.grace_period).to eq(3)
      end
    end

    context "with no preferences set on the customer level" do
      let(:billing_entity) do
        build(
          :billing_entity,
          subscription_invoice_issuing_date_anchor: "current_period_end",
          subscription_invoice_issuing_date_adjustment: "keep_anchor",
          invoice_grace_period: 3
        )
      end

      let(:customer) { build(:customer, billing_entity:) }

      it "returns value based on billing entity settings" do
        expect(issuing_date_service.grace_period).to eq(3)
      end
    end

    context "with no preferences set on the billing_entity level" do
      let(:billing_entity) { build(:billing_entity, invoice_grace_period: nil) }
      let(:customer) { build(:customer, billing_entity:, invoice_grace_period: nil) }

      it "returns 0" do
        expect(issuing_date_service.grace_period).to eq(0)
      end
    end

    context "with customer as a hash" do
      subject(:issuing_date_service) do
        described_class.new(
          customer_settings: {
            subscription_invoice_issuing_date_anchor: "current_period_end",
            subscription_invoice_issuing_date_adjustment: "keep_anchor",
            invoice_grace_period: 3
          },
          billing_entity_settings: customer.billing_entity,
          recurring:
        )
      end

      it "returns value based on customer hash" do
        expect(issuing_date_service.grace_period).to eq(3)
      end
    end

    context "with billing_entity as a hash" do
      subject(:issuing_date_service) do
        described_class.new(
          customer_settings: customer,
          billing_entity_settings: {
            subscription_invoice_issuing_date_anchor: "current_period_end",
            subscription_invoice_issuing_date_adjustment: "keep_anchor",
            invoice_grace_period: 3
          },
          recurring:
        )
      end

      it "returns value based on billing entity hash" do
        expect(issuing_date_service.grace_period).to eq(3)
      end
    end
  end
end
