# frozen_string_literal: true

require "rails_helper"

RSpec.describe Invoices::PreviewContextService do
  let(:result) { described_class.call(organization:, params:, billing_entity:) }

  describe "#call" do
    let(:organization) { create(:organization) }
    let(:plan) { create(:plan, organization:) }
    let(:customer) { create(:customer, organization:) }
    let(:billing_entity) { organization.default_billing_entity }

    let(:params) do
      {
        customer: {external_id: customer.external_id},
        plan_code: plan.code,
        coupons: []
      }
    end

    before do
      create(:coupon, organization:) { create(:applied_coupon, coupon: it, customer:) }
    end

    it "assigns customer, plan, and applied coupons to result" do
      expect(result)
        .to be_success
        .and have_attributes(customer:, subscriptions: [Subscription], applied_coupons: customer.applied_coupons)
    end
  end

  describe "#customer" do
    subject { result.customer }

    let(:organization) { create(:organization) }
    let(:billing_entity) { organization.default_billing_entity }

    before { create(:customer, organization:) }

    context "when customer external id is provided" do
      let(:params) do
        {
          customer: {
            external_id:,
            tax_identification_number: "123",
            currency: "USD",
            address_line1: "Rue de Tax",
            city: "Paris",
            zipcode: "75011",
            country: "IT",
            shipping_address: {
              address_line1: Faker::Address.street_address,
              city: "Paris",
              zipcode: "75011",
              country: "IT"
            },
            integration_customers: [
              {
                integration_type: "anrok",
                integration_code: "code"
              }
            ]
          }
        }
      end

      before { create(:anrok_integration, organization:, code: "code") }

      context "when customer matching external id exists in organization" do
        let(:customer) { create(:customer, organization:) }
        let(:external_id) { customer.external_id }

        context "when integration matching params exists" do
          it "returns customer with overrides from params" do
            expect(subject)
              .to be_a(Customer)
              .and be_persisted
              .and have_attributes(
                id: customer.id,
                name: customer.name,
                currency: params.dig(:customer, :currency),
                address_line1: params.dig(:customer, :address_line1),
                shipping_address_line1: params.dig(:customer, :shipping_address, :address_line1),
                integration_customers: array_including(IntegrationCustomers::AnrokCustomer)
              )
          end

          it "does not change existing customer" do
            expect { subject }.not_to change { customer.reload.updated_at }
          end

          it "does not persist integrations" do
            expect { subject }.not_to change { customer.reload.integration_customers.empty? }
          end
        end

        context "when customer matching external_id with another billing_entity" do
          let(:billing_entity) { create(:billing_entity, organization:) }

          it "does not change existing customer" do
            expect { subject }.not_to change { customer.reload.updated_at }
          end
        end
      end

      context "when customer matching external id does not exist in organization" do
        let(:external_id) { SecureRandom.uuid }

        it "returns nil" do
          expect(result).not_to be_success
          expect(result.error).to be_a(BaseService::NotFoundFailure)
          expect(result.error.error_code).to eq("customer_not_found")

          expect(subject).to be_nil
        end
      end
    end

    context "when customer external id is missing" do
      let(:params) do
        {
          customer: {
            name: "Mislav M",
            tax_identification_number: "123",
            currency: "EUR",
            address_line1: "Rue de Tax",
            address_line2: nil,
            state: nil,
            city: "Paris",
            zipcode: "75011",
            country: "IT",
            shipping_address: {
              address_line1: Faker::Address.street_address,
              address_line2: Faker::Address.street_address,
              city: "Paris",
              state: nil,
              zipcode: "75011",
              country: "IT"
            },
            integration_customers: [
              {
                integration_type: "anrok",
                integration_code: "code"
              }
            ]
          }
        }
      end

      context "when integration matching params exists" do
        let(:expected_attributes) do
          params[:customer].tap do |hash|
            hash[:integration_customers] = array_including(IntegrationCustomers::AnrokCustomer)
            hash[:billing_entity_id] = billing_entity.id
          end
        end

        before { create(:anrok_integration, organization:, code: "code") }

        it "returns new customer build from params including integration customers and default billing_entity" do
          expect(subject)
            .to be_present
            .and be_new_record
            .and have_attributes(expected_attributes)
        end
      end

      context "when integration matching params does not exist" do
        it "returns nil" do
          expect(result).not_to be_success
          expect(result.error).to be_a(BaseService::NotFoundFailure)
          expect(result.error.error_code).to eq("anrok_integration_not_found")

          expect(subject).to be_nil
        end
      end

      context "when an explicit billing_entity is passed for a brand-new customer" do
        let(:billing_entity) { create(:billing_entity, organization:) }
        let(:params) do
          {
            customer: {
              name: "Mislav M",
              currency: "EUR"
            }
          }
        end

        context "when multi_entity_billing flag is disabled" do
          it "builds the customer with the passed billing entity" do
            expect(subject)
              .to be_present
              .and be_new_record
              .and have_attributes(billing_entity_id: billing_entity.id)
          end
        end

        context "when multi_entity_billing flag is enabled" do
          before { organization.enable_feature_flag!(:multi_entity_billing) }

          it "builds the customer with the organization's default billing entity" do
            expect(subject)
              .to be_present
              .and be_new_record
              .and have_attributes(billing_entity_id: organization.default_billing_entity.id)
          end
        end
      end
    end
  end

  describe "#subscriptions" do
    subject { result.subscriptions }

    let(:organization) { customer.organization }
    let(:billing_entity) { organization.default_billing_entity }
    let(:customer) { create(:customer) }

    let(:params) do
      {
        customer: {external_id: customer.external_id},
        plan_code: plan&.code,
        subscription_at: subscription_at&.iso8601,
        billing_time:
      }
    end

    context "with valid params" do
      let(:plan) { create(:plan, organization:) }
      let(:subscription_at) { generate(:past_date) }
      let(:billing_time) { "anniversary" }

      before { freeze_time }

      it "returns new subscription with provided params" do
        expect(subject)
          .to all(
            be_a(Subscription)
              .and(have_attributes(
                customer:,
                plan:,
                subscription_at: subscription_at,
                started_at: subscription_at,
                billing_time: params[:billing_time]
              ))
          )
      end
    end

    context "with invalid params" do
      let(:plan) { nil }
      let(:subscription_at) { nil }
      let(:billing_time) { nil }

      it "returns nil" do
        expect(result).not_to be_success
        expect(result.error).to be_a(BaseService::NotFoundFailure)
        expect(result.error.error_code).to eq("plan_not_found")

        expect(subject).to be_nil
      end
    end
  end

  describe "#applied_coupons" do
    subject { result.applied_coupons }

    let(:organization) { create(:organization) }
    let(:billing_entity) { organization.default_billing_entity }
    let(:plan) { create(:plan, organization:) }

    let(:params) do
      {
        customer: customer_params,
        plan_code: plan.code,
        coupons: coupon_params
      }
    end

    context "when customer has applied coupons" do
      let(:customer_params) { {external_id: customer.external_id} }
      let(:customer) { create(:customer, organization:) }

      before do
        create(:coupon, organization:) { create(:applied_coupon, coupon: it, customer:) }
      end

      context "when coupons are provided" do
        let(:coupon_params) do
          [
            {
              code: coupon.code
            },
            {
              code: "coupon_preview",
              name: "coupon_preview",
              coupon_type: "percentage",
              amount_cents: 1200,
              amount_currency: "EUR",
              percentage_rate: 1
            }
          ]
        end

        let(:coupon) { create(:coupon, organization:) }

        it "returns customer's applied coupons" do
          expect(subject).to be_present.and eq customer.applied_coupons
        end
      end

      context "when coupons are empty" do
        let(:coupon_params) { [] }

        it "returns customer's applied coupons" do
          expect(subject).to be_present.and eq customer.applied_coupons
        end
      end
    end

    context "when customer has no applied coupons" do
      let(:customer_params) { {name: Faker::Name.name} }

      context "when coupons are provided" do
        let(:coupon_params) do
          [
            {
              code: coupon.code
            },
            {
              code: "coupon_preview",
              name: "coupon_preview",
              coupon_type: "percentage",
              amount_cents: 1200,
              amount_currency: "EUR",
              percentage_rate: 1
            }
          ]
        end

        let(:coupon) { create(:coupon, organization:) }

        it "returns applied coupons build from provided params" do
          expect(subject).to be_a(Array).and match_array([AppliedCoupon, AppliedCoupon])

          expect(subject.map { |ac| ac.coupon.code })
            .to match_array coupon_params.map { |i| i[:code] }
        end
      end

      context "when coupons are empty" do
        let(:coupon_params) { [] }

        it "returns empty collection" do
          expect(subject).to be_empty
        end
      end
    end
  end
end
