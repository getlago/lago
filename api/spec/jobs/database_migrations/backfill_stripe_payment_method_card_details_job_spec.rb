# frozen_string_literal: true

require "rails_helper"

RSpec.describe DatabaseMigrations::BackfillStripePaymentMethodCardDetailsJob do
  subject(:perform_job) { described_class.perform_now }

  let(:organization) { create(:organization) }
  let(:customer) { create(:customer, organization:) }
  let(:stripe_provider) { create(:stripe_provider, organization:) }
  let(:stripe_customer) { create(:stripe_customer, customer:, payment_provider: stripe_provider) }
  let(:invoice) { create(:invoice, customer:, organization:) }

  let(:migration_payment_method) do
    create(
      :payment_method,
      customer:,
      payment_provider: stripe_provider,
      payment_provider_customer: stripe_customer,
      provider_method_id: "pm_123",
      details: {"from_migration" => true}
    )
  end

  let(:payment_with_card_details) do
    create(
      :payment,
      payable: invoice,
      organization:,
      payment_provider: stripe_provider,
      payment_provider_customer: stripe_customer,
      provider_payment_method_id: "pm_123",
      provider_payment_method_data: {
        type: "card",
        brand: "visa",
        last4: "4242",
        expiration_month: 12,
        expiration_year: 2028
      }
    )
  end

  context "when payment method has from_migration marker and matching payment data" do
    it "updates the card details on the payment method" do
      migration_payment_method
      payment_with_card_details
      perform_job

      details = migration_payment_method.reload.details
      expect(details["type"]).to eq("card")
      expect(details["brand"]).to eq("visa")
      expect(details["last4"]).to eq("4242")
      expect(details["expiration_month"]).to eq(12)
      expect(details["expiration_year"]).to eq(2028)
      expect(details["from_migration"]).to be true
    end
  end

  context "when payment data has no expiration fields (historical data)" do
    let(:payment_without_expiry) do
      create(
        :payment,
        payable: invoice,
        organization:,
        payment_provider: stripe_provider,
        payment_provider_customer: stripe_customer,
        provider_payment_method_id: "pm_123",
        provider_payment_method_data: {type: "card", brand: "visa", last4: "4242"}
      )
    end

    it "updates only the available fields" do
      migration_payment_method
      payment_without_expiry
      perform_job

      details = migration_payment_method.reload.details
      expect(details["last4"]).to eq("4242")
      expect(details["expiration_month"]).to be_nil
      expect(details["expiration_year"]).to be_nil
    end
  end

  context "when payment method has from_migration marker but no matching payment data" do
    it "does not update the payment method" do
      migration_payment_method

      expect { perform_job }.not_to change { migration_payment_method.reload.details }
    end
  end

  context "when payment method was not created by migration" do
    let(:regular_payment_method) do
      create(
        :payment_method,
        customer:,
        payment_provider: stripe_provider,
        payment_provider_customer: stripe_customer,
        provider_method_id: "pm_123",
        details: {last4: "9999", brand: "mastercard"}
      )
    end

    it "does not touch it" do
      regular_payment_method
      payment_with_card_details

      expect { perform_job }.not_to change { regular_payment_method.reload.details }
    end
  end

  context "when payment method already has card details" do
    let(:already_filled_payment_method) do
      create(
        :payment_method,
        customer:,
        payment_provider: stripe_provider,
        payment_provider_customer: stripe_customer,
        provider_method_id: "pm_123",
        details: {"from_migration" => true, "last4" => "4242", "brand" => "visa"}
      )
    end

    it "does not update it again" do
      already_filled_payment_method
      payment_with_card_details

      expect { perform_job }.not_to change { already_filled_payment_method.reload.updated_at }
    end
  end

  context "when customer has multiple payments for the same method" do
    let(:old_invoice) { create(:invoice, customer:, organization:) }
    let(:recent_invoice) { create(:invoice, customer:, organization:) }

    it "uses card details from the most recent payment" do
      migration_payment_method

      create(
        :payment,
        payable: old_invoice,
        organization:,
        payment_provider: stripe_provider,
        payment_provider_customer: stripe_customer,
        provider_payment_method_id: "pm_123",
        provider_payment_method_data: {type: "card", brand: "visa", last4: "1111"},
        created_at: 2.months.ago
      )
      create(
        :payment,
        payable: recent_invoice,
        organization:,
        payment_provider: stripe_provider,
        payment_provider_customer: stripe_customer,
        provider_payment_method_id: "pm_123",
        provider_payment_method_data: {type: "card", brand: "visa", last4: "4242"},
        created_at: 1.day.ago
      )

      perform_job

      expect(migration_payment_method.reload.details["last4"]).to eq("4242")
    end
  end

  context "with organization_id filter" do
    let(:other_organization) { create(:organization) }
    let(:other_customer) { create(:customer, organization: other_organization) }
    let(:other_stripe_provider) { create(:stripe_provider, organization: other_organization) }
    let(:other_stripe_customer) { create(:stripe_customer, customer: other_customer, payment_provider: other_stripe_provider) }
    let(:other_invoice) { create(:invoice, customer: other_customer, organization: other_organization) }
    let(:other_payment_method) do
      create(
        :payment_method,
        customer: other_customer,
        payment_provider: other_stripe_provider,
        payment_provider_customer: other_stripe_customer,
        provider_method_id: "pm_other",
        details: {"from_migration" => true}
      )
    end

    it "only updates payment methods for the specified organization" do
      migration_payment_method
      payment_with_card_details
      other_payment_method
      create(
        :payment,
        payable: other_invoice,
        organization: other_organization,
        payment_provider: other_stripe_provider,
        payment_provider_customer: other_stripe_customer,
        provider_payment_method_id: "pm_other",
        provider_payment_method_data: {type: "card", brand: "mastercard", last4: "9999"}
      )

      described_class.perform_now(organization.id)

      expect(migration_payment_method.reload.details["last4"]).to eq("4242")
      expect(other_payment_method.reload.details["last4"]).to be_nil
    end
  end

  context "when there is more work after the batch" do
    before { stub_const("#{described_class}::BATCH_SIZE", 1) }

    it "enqueues the next batch" do
      customer_2 = create(:customer, organization:)
      stripe_customer_2 = create(:stripe_customer, customer: customer_2, payment_provider: stripe_provider)
      invoice_2 = create(:invoice, customer: customer_2, organization:)

      migration_payment_method
      payment_with_card_details

      create(
        :payment_method,
        customer: customer_2,
        payment_provider: stripe_provider,
        payment_provider_customer: stripe_customer_2,
        provider_method_id: "pm_456",
        details: {"from_migration" => true}
      )
      create(
        :payment,
        payable: invoice_2,
        organization:,
        payment_provider: stripe_provider,
        payment_provider_customer: stripe_customer_2,
        provider_payment_method_id: "pm_456",
        provider_payment_method_data: {type: "card", brand: "mastercard", last4: "9999"}
      )

      expect { perform_job }.to have_enqueued_job(described_class)
    end
  end
end
