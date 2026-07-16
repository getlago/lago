# frozen_string_literal: true

require "rails_helper"

RSpec.describe DatabaseMigrations::BackfillStripePaymentMethodsJob do
  subject(:perform_job) { described_class.perform_now }

  let(:organization) { create(:organization) }
  let(:customer) { create(:customer, organization:) }
  let(:stripe_provider) { create(:stripe_provider, organization:) }
  let(:stripe_customer) do
    create(:stripe_customer, customer:, payment_provider: stripe_provider).tap do |sc|
      sc.update!(payment_method_id: "pm_123")
    end
  end

  context "when stripe customer has a payment_method_id" do
    it "creates a payment method" do
      stripe_customer

      expect { perform_job }.to change(PaymentMethod, :count).by(1)
    end

    it "sets the correct attributes on the payment method" do
      stripe_customer
      perform_job

      payment_method = customer.payment_methods.first
      expect(payment_method.provider_method_id).to eq("pm_123")
      expect(payment_method.provider_method_type).to eq("card")
      expect(payment_method.payment_provider_customer).to eq(stripe_customer)
      expect(payment_method.payment_provider).to eq(stripe_provider)
      expect(payment_method.organization).to eq(organization)
      expect(payment_method.is_default).to be true
      expect(payment_method.details["from_migration"]).to be true
    end
  end

  context "when stripe customer has no payment_method_id" do
    let(:stripe_customer) { create(:stripe_customer, customer:, payment_provider: stripe_provider) }

    it "does not create a payment method" do
      stripe_customer

      expect { perform_job }.not_to change(PaymentMethod, :count)
    end
  end

  context "when customer has a non-stripe provider customer" do
    let(:gocardless_provider) { create(:gocardless_provider, organization:) }
    let(:gocardless_customer) { create(:gocardless_customer, customer:, payment_provider: gocardless_provider) }

    it "does not create a payment method" do
      gocardless_customer

      expect { perform_job }.not_to change(PaymentMethod, :count)
    end
  end

  context "when customer has no provider customer at all" do
    it "does not create a payment method" do
      customer

      expect { perform_job }.not_to change(PaymentMethod, :count)
    end
  end

  context "when payment method already exists for the stripe customer" do
    it "does not create a duplicate" do
      create(:payment_method, customer:, payment_provider_customer: stripe_customer, provider_method_id: "pm_123")

      expect { perform_job }.not_to change(PaymentMethod, :count)
    end
  end

  context "when a discarded payment method already exists for the stripe customer" do
    it "does not recreate the discarded payment method" do
      create(:payment_method, customer:, payment_provider_customer: stripe_customer, provider_method_id: "pm_123").discard!

      expect { perform_job }.not_to change(PaymentMethod.unscoped, :count)
    end
  end

  context "when multiple customers have stripe customers with payment_method_id" do
    let(:customer_2) { create(:customer, organization:) }
    let(:stripe_customer_2) do
      create(:stripe_customer, customer: customer_2, payment_provider: stripe_provider).tap do |sc|
        sc.update!(payment_method_id: "pm_456")
      end
    end

    it "creates a payment method for each customer" do
      stripe_customer
      stripe_customer_2

      expect { perform_job }.to change(PaymentMethod, :count).by(2)
    end
  end

  context "with organization_id filter" do
    let(:other_organization) { create(:organization) }
    let(:other_customer) { create(:customer, organization: other_organization) }
    let(:other_stripe_provider) { create(:stripe_provider, organization: other_organization) }
    let(:other_stripe_customer) do
      create(:stripe_customer, customer: other_customer, payment_provider: other_stripe_provider).tap do |sc|
        sc.update!(payment_method_id: "pm_other")
      end
    end

    it "only processes the specified organization" do
      stripe_customer
      other_stripe_customer

      expect { described_class.perform_now(organization.id) }
        .to change(PaymentMethod, :count).by(1)

      expect(customer.payment_methods.count).to eq(1)
      expect(other_customer.payment_methods.count).to eq(0)
    end
  end

  context "when there is more work after the batch" do
    before { stub_const("#{described_class}::BATCH_SIZE", 1) }

    it "enqueues the next batch" do
      customer_2 = create(:customer, organization:)
      stripe_customer
      create(:stripe_customer, customer: customer_2, payment_provider: stripe_provider).tap do |sc|
        sc.update!(payment_method_id: "pm_456")
      end

      expect { perform_job }.to have_enqueued_job(described_class)
    end
  end

  context "when there is no pending work" do
    it "enqueues BackfillStripePaymentMethodCardDetailsJob" do
      expect { perform_job }
        .to have_enqueued_job(DatabaseMigrations::BackfillStripePaymentMethodCardDetailsJob)
    end
  end
end
