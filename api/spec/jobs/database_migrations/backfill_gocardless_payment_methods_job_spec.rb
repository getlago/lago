# frozen_string_literal: true

require "rails_helper"

RSpec.describe DatabaseMigrations::BackfillGocardlessPaymentMethodsJob do
  subject(:perform_job) { described_class.perform_now }

  let(:organization) { create(:organization) }
  let(:customer) { create(:customer, organization:) }
  let(:gocardless_provider) { create(:gocardless_provider, organization:) }
  let(:gocardless_customer) do
    create(:gocardless_customer, customer:, payment_provider: gocardless_provider).tap do |c|
      c.update!(provider_mandate_id: "mandate_123", provider_customer_id: "gc_customer_123")
    end
  end

  context "when gocardless customer has a provider_mandate_id" do
    it "creates a payment method" do
      gocardless_customer

      expect { perform_job }.to change(PaymentMethod, :count).by(1)
    end

    it "sets the correct attributes on the payment method" do
      gocardless_customer
      perform_job

      payment_method = customer.payment_methods.first
      expect(payment_method.provider_method_id).to eq("mandate_123")
      expect(payment_method.provider_method_type).to eq("card")
      expect(payment_method.payment_provider_customer).to eq(gocardless_customer)
      expect(payment_method.payment_provider).to eq(gocardless_provider)
      expect(payment_method.organization).to eq(organization)
      expect(payment_method.is_default).to be true
      expect(payment_method.details["from_migration"]).to be true
      expect(payment_method.details["provider_customer_id"]).to eq("gc_customer_123")
    end
  end

  context "when gocardless customer has no provider_mandate_id" do
    let(:gocardless_customer) { create(:gocardless_customer, customer:, payment_provider: gocardless_provider) }

    it "does not create a payment method" do
      gocardless_customer

      expect { perform_job }.not_to change(PaymentMethod, :count)
    end
  end

  context "when payment method already exists for the gocardless customer" do
    it "does not create a duplicate" do
      create(:payment_method, customer:, payment_provider_customer: gocardless_customer, provider_method_id: "mandate_123")

      expect { perform_job }.not_to change(PaymentMethod, :count)
    end
  end

  context "when a discarded payment method already exists for the gocardless customer" do
    it "does not recreate the discarded payment method" do
      create(:payment_method, customer:, payment_provider_customer: gocardless_customer, provider_method_id: "mandate_123").discard!

      expect { perform_job }.not_to change(PaymentMethod.unscoped, :count)
    end
  end

  context "with organization_id filter" do
    let(:other_organization) { create(:organization) }
    let(:other_customer) { create(:customer, organization: other_organization) }
    let(:other_gocardless_provider) { create(:gocardless_provider, organization: other_organization) }
    let(:other_gocardless_customer) do
      create(:gocardless_customer, customer: other_customer, payment_provider: other_gocardless_provider).tap do |c|
        c.update!(provider_mandate_id: "mandate_other")
      end
    end

    it "only processes the specified organization" do
      gocardless_customer
      other_gocardless_customer

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
      gocardless_customer
      create(:gocardless_customer, customer: customer_2, payment_provider: gocardless_provider).tap do |c|
        c.update!(provider_mandate_id: "mandate_456")
      end

      expect { perform_job }.to have_enqueued_job(described_class)
    end
  end

  context "when there is no pending work" do
    it "does not enqueue any job" do
      expect { perform_job }.not_to have_enqueued_job
    end
  end
end
