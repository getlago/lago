# frozen_string_literal: true

require "rails_helper"

RSpec.describe Api::V1::SubscriptionsController, :premium do
  let(:organization) { create(:organization, premium_integrations: %w[progressive_billing]) }
  let(:customer) { create(:customer, organization:) }
  let(:plan) { create(:plan, organization:, amount_cents: 500, description: "desc") }
  let(:plan_usage_threshold) { create(:usage_threshold, plan:, amount_cents: 10_00, threshold_display_name: "Init") }
  let(:commitment_invoice_display_name) { "Overriden minimum commitment name" }
  let(:commitment_amount_cents) { 1234 }
  let(:section_1) { create(:invoice_custom_section, organization:, code: "section_code_1") }
  let(:payment_method) { create(:payment_method, customer:, organization:) }

  before do
    plan_usage_threshold
  end

  describe "POST /api/v1/subscriptions" do
    subject { post_with_token(organization, "/api/v1/subscriptions", body) }

    let(:body) { {subscription: params} }
    let(:subscription_at) { Time.current.iso8601 }
    let(:ending_at) { (Time.current + 1.year).iso8601 }
    let(:plan_code) { plan.code }
    let(:plan_amount_cents_override) { 100 }

    let(:params) do
      {
        external_customer_id: customer.external_id,
        plan_code:,
        name: "subscription name",
        external_id: SecureRandom.uuid,
        billing_time: "anniversary",
        subscription_at:,
        ending_at:,
        invoice_custom_section: {
          invoice_custom_section_codes: [section_1.code]
        },
        payment_method: {
          payment_method_id: payment_method&.id,
          payment_method_type: "provider"
        },
        plan_overrides: {
          amount_cents: plan_amount_cents_override,
          name: "overridden name",
          minimum_commitment: {
            invoice_display_name: commitment_invoice_display_name,
            amount_cents: commitment_amount_cents
          }
        }
      }
    end

    let(:override_amount_cents) { 777 }
    let(:override_display_name) { "Overriden Threshold 12" }

    before do
      customer
      payment_method
    end

    include_examples "requires API permission", "subscription", "write"

    it "returns a success" do
      create(:plan, code: plan.code, parent_id: plan.id, organization:, description: "foo")
      create(:entitlement, organization:, plan:)

      freeze_time do
        subject

        expect(response).to have_http_status(:ok)
        expect(json[:subscription]).to include(
          lago_id: String,
          external_id: String,
          external_customer_id: customer.external_id,
          lago_customer_id: customer.id,
          plan_code: plan.code,
          plan_amount_cents: plan_amount_cents_override,
          plan_amount_currency: plan.amount_currency,
          status: "active",
          name: "subscription name",
          started_at: String,
          billing_time: "anniversary",
          subscription_at: Time.current.iso8601,
          ending_at: (Time.current + 1.year).iso8601,
          previous_plan_code: nil,
          next_plan_code: nil,
          downgrade_plan_date: nil
        )
        expect(json[:subscription][:entitlements]).to contain_exactly({
          code: "feature_1",
          name: "Feature Name",
          description: "Feature Description",
          privileges: [],
          overrides: {}
        })
        expect(json[:subscription][:plan]).to include(
          amount_cents: plan_amount_cents_override,
          name: "overridden name",
          description: "desc"
        )
        expect(json[:subscription][:plan][:minimum_commitment]).to include(
          invoice_display_name: commitment_invoice_display_name,
          amount_cents: commitment_amount_cents
        )
        expect(json[:subscription][:payment_method][:payment_method_type]).to eq("provider")
        expect(json[:subscription][:payment_method][:payment_method_id]).to eq(payment_method.id)
      end
    end

    it "doesn't create a new customer" do
      expect { subject }.not_to change(Customer, :count)
    end

    context "when usage_thresholds is part of plan_override (legacy)" do
      let(:params) do
        {
          external_customer_id: customer.external_id,
          plan_code:,
          external_id: SecureRandom.uuid,
          billing_time: "anniversary",
          subscription_at:,
          ending_at:,
          plan_overrides: {
            usage_thresholds: [
              amount_cents: override_amount_cents,
              threshold_display_name: override_display_name
            ]
          }
        }
      end

      it "attaches the usage_thresholds to the child plan" do
        subject

        expect(response).to have_http_status(:ok)

        expect(plan.usage_thresholds).to contain_exactly(plan_usage_threshold)
        subscription = Subscription.find json[:subscription][:lago_id]
        expect(subscription.plan.is_child?).to be true
        expect(subscription.plan.usage_thresholds.sole.amount_cents).to eq override_amount_cents
        expect(subscription.usage_thresholds).to be_empty

        expect(json[:subscription][:applicable_usage_thresholds]).to contain_exactly(
          {
            amount_cents: override_amount_cents,
            threshold_display_name: override_display_name,
            recurring: false
          }
        )
        expect(json[:subscription][:plan][:usage_thresholds]).to contain_exactly(
          hash_including(
            amount_cents: override_amount_cents,
            threshold_display_name: override_display_name,
            recurring: false
          )
        )
        expect(json[:subscription][:plan][:applicable_usage_thresholds]).to contain_exactly({
          amount_cents: plan_usage_threshold.amount_cents,
          threshold_display_name: plan_usage_threshold.threshold_display_name,
          recurring: false
        })
      end
    end

    context "when usage_thresholds is part of subscription" do
      let(:params) do
        {
          external_customer_id: customer.external_id,
          plan_code:,
          external_id: SecureRandom.uuid,
          billing_time: "anniversary",
          subscription_at:,
          ending_at:,
          usage_thresholds: [
            amount_cents: override_amount_cents,
            threshold_display_name: override_display_name
          ],
          plan_overrides: {
            amount_cents: 99_99
          }
        }
      end

      it "attaches the usage_thresholds to the subscription" do
        subject

        expect(response).to have_http_status(:ok)

        expect(plan.usage_thresholds).to contain_exactly(plan_usage_threshold)
        subscription = Subscription.find json[:subscription][:lago_id]
        expect(subscription.plan.is_child?).to be true
        expect(subscription.plan.usage_thresholds).to be_empty
        expect(subscription.usage_thresholds.sole.amount_cents).to eq override_amount_cents

        expect(json[:subscription][:applicable_usage_thresholds]).to contain_exactly(
          {
            amount_cents: override_amount_cents,
            threshold_display_name: override_display_name,
            recurring: false
          }
        )
        expect(json[:subscription][:plan][:usage_thresholds]).to be_empty
        expect(json[:subscription][:plan][:applicable_usage_thresholds]).to contain_exactly({
          amount_cents: plan_usage_threshold.amount_cents,
          threshold_display_name: plan_usage_threshold.threshold_display_name,
          recurring: false
        })
      end
    end

    context "with external_customer_id, external_id and name as integer" do
      let(:params) do
        {
          external_customer_id: 123,
          plan_code:,
          name: 456,
          external_id: 789
        }
      end

      it "returns a success" do
        subject

        expect(response).to have_http_status(:ok)
        expect(json[:subscription]).to include(
          lago_id: String,
          external_customer_id: "123",
          name: "456",
          external_id: "789"
        )
      end

      it "creates a new customer in the organization default billing entity" do
        expect { subject }.to change(Customer, :count).by(1)

        customer = Customer.find_by(external_id: "123")
        expect(customer.organization).to eq(organization)
        expect(customer.billing_entity).to eq(organization.default_billing_entity)
      end

      context "when passing billing_entity_code" do
        let(:billing_entity) { create(:billing_entity, organization:) }
        let(:params) do
          {
            external_customer_id: 123,
            plan_code:,
            name: 456,
            external_id: 789,
            billing_entity_code: billing_entity.code
          }
        end

        it "creates a new customer with the given billing entity" do
          expect { subject }.to change(Customer, :count).by(1)

          customer = Customer.find_by(external_id: "123")
          expect(customer.billing_entity).to eq(billing_entity)
        end

        context "when billing entity does not exist" do
          let(:params) do
            {
              external_customer_id: 123,
              plan_code:,
              name: 456,
              external_id: 789,
              billing_entity_code: SecureRandom.uuid
            }
          end

          it "returns a not_found error" do
            subject

            expect(response).to have_http_status(:not_found)
            expect(json[:code]).to eq("billing_entity_not_found")
          end
        end

        context "when passing external_id from another billing entity" do
          let(:params) do
            {
              external_customer_id: customer.external_id,
              plan_code:,
              name: 456,
              external_id: 789,
              billing_entity_code: billing_entity.id
            }
          end

          it "uses the customer ignoring billing_entity" do
            expect { subject }.not_to change(Customer, :count)

            customer.reload
            expect(customer.billing_entity).to eq(organization.default_billing_entity)
          end
        end
      end
    end

    context "without external_customer_id" do
      let(:params) do
        {
          plan_code:,
          name: "subscription name",
          external_id: SecureRandom.uuid
        }
      end

      it "returns an unprocessable_entity error" do
        subject

        expect(response).to have_http_status(:unprocessable_content)
        expect(json[:error_details]).to eq({external_customer_id: %w[value_is_mandatory]})
      end
    end

    context "when binding the subscription to an explicit billing entity" do
      let(:billing_entity) { create(:billing_entity, organization:) }
      let(:params) do
        {
          external_customer_id: customer.external_id,
          plan_code:,
          external_id: SecureRandom.uuid,
          billing_time: "anniversary",
          billing_entity_code: billing_entity.code
        }
      end

      context "when multi_entity_billing flag is enabled" do
        before { organization.enable_feature_flag!(:multi_entity_billing) }

        it "binds the subscription to the resolved billing entity" do
          subject

          expect(response).to have_http_status(:ok)
          subscription = Subscription.find_by(external_id: params[:external_id])
          expect(subscription.billing_entity_id).to eq(billing_entity.id)
        end

        context "when binding via billing_entity_id instead of code" do
          let(:params) do
            {
              external_customer_id: customer.external_id,
              plan_code:,
              external_id: SecureRandom.uuid,
              billing_time: "anniversary",
              billing_entity_id: billing_entity.id
            }
          end

          it "binds the subscription to the resolved billing entity" do
            subject

            expect(response).to have_http_status(:ok)
            subscription = Subscription.find_by(external_id: params[:external_id])
            expect(subscription.billing_entity_id).to eq(billing_entity.id)
          end
        end
      end

      context "when multi_entity_billing flag is disabled" do
        it "ignores the param and persists subscription with no explicit billing entity" do
          subject

          expect(response).to have_http_status(:ok)
          subscription = Subscription.find_by(external_id: params[:external_id])
          expect(subscription.billing_entity_id).to be_nil
        end
      end

      context "without billing_entity_code" do
        let(:params) do
          {
            external_customer_id: customer.external_id,
            plan_code:,
            external_id: SecureRandom.uuid,
            billing_time: "anniversary"
          }
        end

        before { organization.enable_feature_flag!(:multi_entity_billing) }

        it "persists subscription with no explicit billing entity" do
          subject

          expect(response).to have_http_status(:ok)
          subscription = Subscription.find_by(external_id: params[:external_id])
          expect(subscription.billing_entity_id).to be_nil
        end
      end
    end

    context "with invalid plan code" do
      let(:plan_code) { "#{plan.code}-invalid" }

      it "returns a not_found error" do
        subject
        expect(response).to have_http_status(:not_found)
      end
    end

    context "with invalid subscription_at" do
      let(:subscription_at) { "hello" }

      it "returns an unprocessable_entity error" do
        subject
        expect(response).to have_http_status(:unprocessable_content)
      end
    end

    context "with legacy subscription_date" do
      let(:params) do
        {
          external_customer_id: customer.external_id,
          plan_code:,
          name: "subscription name",
          external_id: SecureRandom.uuid,
          billing_time: "anniversary",
          subscription_at: subscription_at
        }
      end

      it "returns a success" do
        subject

        expect(response).to have_http_status(:ok)

        expect(json[:subscription][:lago_id]).to be_present
        expect(json[:subscription][:external_id]).to be_present
        expect(json[:subscription][:external_customer_id]).to eq(customer.external_id)
        expect(json[:subscription][:lago_customer_id]).to eq(customer.id)
        expect(json[:subscription][:plan_code]).to eq(plan.code)
        expect(json[:subscription][:plan_amount_cents]).to eq(plan.amount_cents)
        expect(json[:subscription][:plan_amount_currency]).to eq(plan.amount_currency)
        expect(json[:subscription][:status]).to eq("active")
        expect(json[:subscription][:name]).to eq("subscription name")
        expect(json[:subscription][:started_at]).to be_present
        expect(json[:subscription][:billing_time]).to eq("anniversary")
        expect(json[:subscription][:subscription_at]).to eq(Time.zone.parse(subscription_at).iso8601)
        expect(json[:subscription][:previous_plan_code]).to be_nil
        expect(json[:subscription][:next_plan_code]).to be_nil
        expect(json[:subscription][:downgrade_plan_date]).to be_nil
      end
    end

    context "with payment pre-authorization" do
      context "when the feature isn't enabled" do
        let(:body) { {authorization: {}, subscription: params} }

        it "returns a forbidden error" do
          subject

          expect(response).to have_http_status(:forbidden)
          expect(json[:message]).to match(/beta_payment_authorization/)
        end
      end

      context "when the feature is enabled" do
        let(:organization) { create(:organization, premium_integrations: ["beta_payment_authorization"]) }
        let(:body) do
          {
            authorization: {amount_cents: "100", amount_currency: "USD"},
            subscription: params
          }
        end
        let(:customer) { create(:customer, organization:, payment_provider: :stripe, external_id: "cust_12345") }
        let(:stripe_customer) { create(:stripe_customer, customer:, payment_provider: create(:stripe_provider, organization:), payment_method_id: "pm_12345") }
        let(:stripe_pi) do
          {
            id: "pi_12345",
            amount: "100",
            amount_capturable: "100",
            status: "requires_capture"
          }
        end

        before do
          stripe_customer
          stub_request(:post, "https://api.stripe.com/v1/payment_intents").and_return(status: 200, body: stripe_pi.to_json)
        end

        it "returns a success" do
          allow(PaymentProviders::CancelPaymentAuthorizationJob).to receive(:perform_later)

          subject
          expect(json[:authorization]).to include(stripe_pi)
          expect(json[:subscription]).to include(status: "active")

          expect(PaymentProviders::CancelPaymentAuthorizationJob).to have_received(:perform_later).with(
            payment_provider: stripe_customer.payment_provider, id: stripe_pi[:id]
          )
        end

        context "when parameters are incorrect" do
          let(:body) do
            {
              authorization: {amount_cents: "100"},
              subscription: params
            }
          end

          it "returns an error" do
            subject

            expect(response).to have_http_status(:bad_request)
            expect(json[:error]).to eq "BadRequest: param is missing or the value is empty or invalid: amount_currency"
          end
        end

        context "when customer has no payment method" do
          let(:provider_customer_id) { "cus_Rw5Qso78STEap3" }
          let(:stripe_customer) { create(:stripe_customer, customer:, provider_customer_id:, payment_provider: create(:stripe_provider, organization:), payment_method_id: nil) }
          let(:payment_method) { nil }

          context "when customer has a default payment method on Stripe" do
            it do
              stub_request(:get, %r{/v1/customers/#{provider_customer_id}$}).and_return(
                status: 200, body: get_stripe_fixtures("customer_retrieve_response.json")
              )
              stub_request(:get, %r{/v1/customers/#{provider_customer_id}/payment_methods}).and_return(
                status: 200, body: get_stripe_fixtures("customer_list_payment_methods_empty_response.json")
              )

              subject

              expect(response).to have_http_status(:unprocessable_content)
              expect(json[:error_details][:payment_method_id]).to include "customer_has_no_payment_method"
            end
          end
        end

        context "when the authorization failed (card declined)" do
          it do
            stripe_card_declined = get_stripe_fixtures("payment_intent_authorization_failed_response.json")
            stub_request(:post, %r{/v1/payment_intents}).and_return(
              status: 402,
              body: stripe_card_declined,
              headers: {"request-id" => "req_R6dwJQCrHDQkZr"}
            )
            subject

            expect(response).to have_http_status(:unprocessable_content)
            expect(json[:code]).to eq "provider_error"
            expect(json[:provider][:code]).to start_with "stripe_account_"
            expect(json[:error_details]).to include({
              code: "card_declined",
              message: "Your card was declined.",
              request_id: "req_R6dwJQCrHDQkZr",
              http_status: 402
            })
          end
        end
      end
    end

    context "with fixed charges override" do
      let(:plan) { create(:plan, organization:) }
      let(:fixed_charge) { create(:fixed_charge, plan:, units: 2, charge_model: "standard", properties: {amount: "10"}) }
      let(:tax) { create(:tax, organization:) }
      let(:params) do
        {
          external_customer_id: customer.external_id,
          plan_code:,
          name: "subscription name",
          external_id: SecureRandom.uuid,
          billing_time: "anniversary",
          subscription_at:,
          ending_at:,
          plan_overrides: {
            fixed_charges: [{
              id: fixed_charge.id,
              units: "10",
              invoice_display_name: "another name",
              properties: {amount: "20"},
              tax_codes: [tax.code]
            }]
          }
        }
      end

      it "creates a subscription with overridden plan with fixed_charges, but does not send them in the response" do
        subject

        expect(response).to have_http_status(:success)
        expect(json[:subscription][:plan][:fixed_charges]).to be_nil
        subscription = Subscription.find_by(external_id: json[:subscription][:external_id])
        expect(subscription.fixed_charges.count).to eq(1)
        expect(subscription.fixed_charges.first.attributes.symbolize_keys).to include(
          add_on_id: fixed_charge.add_on.id,
          units: 10.0,
          invoice_display_name: "another name",
          charge_model: "standard",
          properties: {"amount" => "20"},
          parent_id: fixed_charge.id
        )
      end

      it "creates fixed charge events for the subscription" do
        subject

        subscription = Subscription.find_by(external_id: json[:subscription][:external_id])
        fixed_charge_override = FixedCharge.find_by(parent_id: fixed_charge.id)
        expect(subscription.fixed_charge_events.count).to eq(1)
        expect(subscription.fixed_charge_events.first.fixed_charge_id).to eq(fixed_charge_override.id)
        expect(subscription.fixed_charge_events.first.timestamp).to be_within(5.seconds).of(Time.current)
      end
    end

    context "with invoice_custom_section" do
      let(:skip_invoice_custom_sections) { false }
      let(:custom_section_codes) { ["section_code_1"] }
      let(:section_1) { create(:invoice_custom_section, organization:, code: "section_code_1") }
      let(:params) do
        {
          external_customer_id: 123,
          plan_code:,
          name: 456,
          external_id: 789,
          invoice_custom_section: {
            skip_invoice_custom_sections:,
            invoice_custom_section_codes: custom_section_codes
          }
        }
      end

      context "when skip_invoice_custom_sections is true" do
        let(:skip_invoice_custom_sections) { true }

        it "create the subscription without custom sections" do
          subject

          subscription = Subscription.find_by(external_id: json[:subscription][:external_id])
          expect(subscription.skip_invoice_custom_sections).to be_truthy
          expect(subscription.applied_invoice_custom_sections.count).to be_zero
        end
      end

      context "when skip_invoice_custom_sections is false" do
        let(:skip_invoice_custom_sections) { false }

        context "without invoice_custom_section_codes" do
          let(:custom_section_codes) { [] }

          it "create the subscription without custom sections" do
            subject

            subscription = Subscription.find_by(external_id: json[:subscription][:external_id])
            expect(subscription.skip_invoice_custom_sections).to be_falsey
            expect(subscription.applied_invoice_custom_sections.count).to be_zero
          end
        end

        context "with invoice_custom_section_codes" do
          let(:custom_section_codes) { [section_1.code] }

          it "create the subscription with custom sections" do
            subject

            subscription = Subscription.find_by(external_id: json[:subscription][:external_id])
            expect(subscription.skip_invoice_custom_sections).to be_falsey
            expect(subscription.applied_invoice_custom_sections.count).to eq(1)
            expect(subscription.applied_invoice_custom_sections.pluck(:invoice_custom_section_id)).to include(section_1.id)
          end
        end
      end
    end

    context "with progressive_billing_disabled" do
      let(:params) do
        {
          external_customer_id: customer.external_id,
          plan_code:,
          external_id: SecureRandom.uuid,
          progressive_billing_disabled: true
        }
      end

      it "creates a subscription with progressive_billing_disabled set to true" do
        subject

        expect(response).to have_http_status(:success)
        expect(json[:subscription][:progressive_billing_disabled]).to be(true)

        subscription = Subscription.find_by(external_id: json[:subscription][:external_id])
        expect(subscription.progressive_billing_disabled).to be(true)
      end
    end

    context "with consolidate_invoice" do
      let(:params) do
        {
          external_customer_id: customer.external_id,
          plan_code:,
          external_id: SecureRandom.uuid,
          consolidate_invoice: false
        }
      end

      it "creates a subscription opted out of invoice consolidation" do
        subject

        expect(response).to have_http_status(:success)
        expect(json[:subscription][:consolidate_invoice]).to be(false)

        subscription = Subscription.find_by(external_id: json[:subscription][:external_id])
        expect(subscription.consolidate_invoice).to be(false)
      end
    end

    context "when consolidate_invoice is omitted" do
      let(:params) do
        {
          external_customer_id: customer.external_id,
          plan_code:,
          external_id: SecureRandom.uuid
        }
      end

      it "defaults consolidate_invoice to true" do
        subject

        expect(response).to have_http_status(:success)
        expect(json[:subscription][:consolidate_invoice]).to be(true)
      end
    end

    context "with applied_invoice_custom_sections in response" do
      it "includes applied_invoice_custom_sections in the serialized response" do
        subject

        expect(response).to have_http_status(:success)

        subscription = Subscription.find_by(external_id: json[:subscription][:external_id])
        expect(json[:subscription][:applied_invoice_custom_sections]).to be_an(Array)
        expect(json[:subscription][:applied_invoice_custom_sections].count).to eq(subscription.applied_invoice_custom_sections.count)
      end
    end

    context "with activation_rules" do
      let(:customer) { create(:customer, organization:, payment_provider: "stripe") }
      let(:subscription_at) { (Time.current + 5.days).iso8601 }

      let(:params) do
        {
          external_customer_id: customer.external_id,
          plan_code: plan.code,
          external_id: SecureRandom.uuid,
          billing_time: "anniversary",
          subscription_at:,
          activation_rules: [{type: "payment", timeout_hours: 48}]
        }
      end

      it "creates subscription with activation rules and returns them" do
        subject

        expect(response).to have_http_status(:ok)
        expect(json[:subscription][:status]).to eq("pending")
        expect(json[:subscription][:cancellation_reason]).to be_nil
        expect(json[:subscription][:activated_at]).to be_nil
        expect(json[:subscription][:activation_rules].size).to eq(1)
        expect(json[:subscription][:activation_rules].first).to include(
          lago_id: String,
          type: "payment",
          timeout_hours: 48,
          status: "inactive",
          expires_at: nil
        )
      end

      context "when timeout_hours is omitted" do
        let(:params) do
          {
            external_customer_id: customer.external_id,
            plan_code: plan.code,
            external_id: SecureRandom.uuid,
            billing_time: "anniversary",
            subscription_at:,
            activation_rules: [{type: "payment"}]
          }
        end

        it "persists rule with default timeout_hours of 0" do
          subject

          expect(response).to have_http_status(:ok)
          expect(json[:subscription][:activation_rules].first[:timeout_hours]).to eq(0)
        end
      end

      context "with invalid rule type" do
        let(:params) do
          {
            external_customer_id: customer.external_id,
            plan_code: plan.code,
            external_id: SecureRandom.uuid,
            billing_time: "anniversary",
            subscription_at:,
            activation_rules: [{type: "unknown"}]
          }
        end

        it "returns an unprocessable_entity error" do
          subject

          expect(response).to have_http_status(:unprocessable_content)
          expect(json[:error_details]).to eq({activation_rules: %w[invalid_type]})
        end
      end

      context "with negative timeout_hours" do
        let(:params) do
          {
            external_customer_id: customer.external_id,
            plan_code: plan.code,
            external_id: SecureRandom.uuid,
            billing_time: "anniversary",
            subscription_at:,
            activation_rules: [{type: "payment", timeout_hours: -1}]
          }
        end

        it "returns an unprocessable_entity error" do
          subject

          expect(response).to have_http_status(:unprocessable_content)
          expect(json[:error_details]).to eq({timeout_hours: %w[value_must_be_positive_or_zero]})
        end
      end

      context "with manual payment method" do
        let(:params) do
          {
            external_customer_id: customer.external_id,
            plan_code: plan.code,
            external_id: SecureRandom.uuid,
            billing_time: "anniversary",
            subscription_at:,
            activation_rules: [{type: "payment", timeout_hours: 48}],
            payment_method: {payment_method_type: "manual"}
          }
        end

        it "returns an unprocessable_entity error" do
          subject

          expect(response).to have_http_status(:unprocessable_content)
          expect(json[:error_details]).to eq({customer: %w[manual_payment_method_invalid_for_payment_activation_rules]})
        end
      end

      context "when customer has no payment provider" do
        let(:customer) { create(:customer, organization:, payment_provider: nil) }

        it "returns an unprocessable_entity error" do
          subject

          expect(response).to have_http_status(:unprocessable_content)
          expect(json[:error_details]).to eq({customer: %w[no_linked_payment_provider]})
        end
      end
    end
  end

  describe "DELETE /api/v1/subscriptions/:external_id" do
    subject { delete_with_token(organization, "/api/v1/subscriptions/#{external_id}", params) }

    let(:subscription) { create(:subscription, customer:, plan:) }
    let(:external_id) { subscription.external_id }
    let(:params) { {} }

    include_examples "requires API permission", "subscription", "write"

    def test_termination(expected_on_termination_credit_note: nil, expected_on_termination_invoice: "generate")
      subject

      expect(response).to have_http_status(:success)
      expect(json[:subscription][:lago_id]).to eq(subscription.id)
      expect(json[:subscription][:status]).to eq("terminated")
      expect(json[:subscription][:terminated_at]).to be_present
      expect(json[:subscription][:on_termination_credit_note]).to eq(expected_on_termination_credit_note)
      expect(json[:subscription][:on_termination_invoice]).to eq(expected_on_termination_invoice)
    end

    it "terminates a subscription" do
      test_termination(expected_on_termination_credit_note: nil)
    end

    context "when plan is pay_in_arrears" do
      let(:params) { {on_termination_credit_note: "credit"} }

      it "terminates subscription but ignores on_termination_credit_note" do
        test_termination(expected_on_termination_credit_note: nil)
      end
    end

    context "when plan is pay_in_advance" do
      let(:plan) { create(:plan, :pay_in_advance, organization:) }
      let(:subscription) { create(:subscription, customer:, plan:) }

      context "without on_termination_credit_note parameter" do
        it "terminates subscription with credit note behavior" do
          test_termination(expected_on_termination_credit_note: "credit")
        end
      end

      context "with on_termination_credit_note parameter" do
        [nil, "", "credit"].each do |on_termination_credit_note|
          context "when on_termination_credit_note is #{on_termination_credit_note.inspect}" do
            let(:params) { {on_termination_credit_note:}.compact }

            it "terminates subscription with credit note behavior" do
              test_termination(expected_on_termination_credit_note: "credit")
            end
          end
        end

        context "when on_termination_credit_note is skip" do
          let(:params) { {on_termination_credit_note: "skip"} }

          it "terminates subscription with skip behavior" do
            test_termination(expected_on_termination_credit_note: "skip")
          end
        end

        context "when on_termination_credit_note is refund" do
          let(:params) { {on_termination_credit_note: "refund"} }

          it "terminates subscription with refund behavior" do
            test_termination(expected_on_termination_credit_note: "refund")
          end
        end

        context "with invalid on_termination_credit_note value" do
          let(:params) { {on_termination_credit_note: "invalid"} }

          it "returns validation error" do
            subject

            expect(response).to have_http_status(:unprocessable_content)
            expect(json[:error_details]).to include(
              on_termination_credit_note: ["invalid_value"]
            )
          end
        end
      end
    end

    context "with on_termination_invoice parameter" do
      context "when on_termination_invoice is generate" do
        let(:params) { {on_termination_invoice: "generate"} }

        it "terminates subscription with generate invoice behavior" do
          test_termination(expected_on_termination_invoice: "generate")
        end
      end

      context "when on_termination_invoice is skip" do
        let(:params) { {on_termination_invoice: "skip"} }

        it "terminates subscription with skip invoice behavior" do
          test_termination(expected_on_termination_invoice: "skip")
        end
      end

      context "with invalid on_termination_invoice value" do
        let(:params) { {on_termination_invoice: "invalid"} }

        it "returns validation error" do
          subject

          expect(response).to have_http_status(:unprocessable_content)
          expect(json[:error_details]).to include(
            on_termination_invoice: ["invalid_value"]
          )
        end
      end

      context "with both on_termination_credit_note and on_termination_invoice parameters" do
        let(:plan) { create(:plan, :pay_in_advance, organization:) }
        let(:subscription) { create(:subscription, customer:, plan:) }
        let(:params) { {on_termination_credit_note: "skip", on_termination_invoice: "skip"} }

        it "terminates subscription with both behaviors" do
          test_termination(expected_on_termination_credit_note: "skip", expected_on_termination_invoice: "skip")
        end
      end
    end

    context "when subscription is pending" do
      let(:subscription) { create(:subscription, :pending, customer:, plan:) }

      it "returns a not found error" do
        subject

        expect(response).to have_http_status(:not_found)
      end

      context "when status is given" do
        let(:params) { {status: "pending"} }

        it "cancels the subscription" do
          subject

          expect(response).to have_http_status(:success)
          expect(json[:subscription][:lago_id]).to eq(subscription.id)
          expect(json[:subscription][:status]).to eq("canceled")
          expect(json[:subscription][:canceled_at]).to be_present
        end
      end
    end

    context "with not existing subscription" do
      let(:external_id) { SecureRandom.uuid }

      it "returns a not found error" do
        subject
        expect(response).to have_http_status(:not_found)
      end
    end

    context "with applied_invoice_custom_sections in response" do
      before { create(:subscription_applied_invoice_custom_section, subscription:) }

      it "includes applied_invoice_custom_sections as an array in the serialized response" do
        subject

        expect(response).to have_http_status(:success)
        expect(json[:subscription][:applied_invoice_custom_sections]).to be_an(Array)
        expect(json[:subscription][:applied_invoice_custom_sections].count).to eq(1)
      end
    end
  end

  describe "PUT /api/v1/subscriptions/:external_id" do
    subject do
      put_with_token(
        organization,
        "/api/v1/subscriptions/#{external_id}",
        params
      )
    end

    let(:params) { {subscription: update_params} }
    let(:subscription) { create(:subscription, :pending, customer:, plan:) }
    let(:external_id) { subscription.external_id }

    let(:update_params) do
      {
        name: "subscription name new",
        subscription_at: "2022-09-05T12:23:12Z",
        invoice_custom_section: {
          skip_invoice_custom_sections: false,
          invoice_custom_section_codes: [section_1.code]
        },
        plan_overrides: {
          name: "Override",
          invoice_display_name: "Override plan",
          interval: "monthly",
          description: "This plan is used to test the override functionality",
          amount_cents: 200,
          amount_currency: "USD",
          charges: [
            {
              applied_pricing_unit: {code: pricing_unit.code, conversion_rate: "2"},
              billable_metric_id: package_charge.billable_metric.id,
              charge_model: "package",
              id: package_charge.id,
              invoice_display_name: "Setup",
              invoiceable: true,
              min_amount_cents: 6000,
              properties: {amount: "60", free_units: 200, package_size: 2000},
              tax_codes: [tax.code]
            },
            # This charge should be ignored as no id is provided
            {
              billable_metric_id: other_billable_metric.id,
              charge_model: "package",
              invoice_display_name: "Setup 2",
              invoiceable: true,
              min_amount_cents: 6000,
              properties: {amount: "60", free_units: 200, package_size: 2000},
              tax_codes: [tax.code]
            }
          ],
          minimum_commitment: {
            invoice_display_name: commitment_invoice_display_name,
            amount_cents: commitment_amount_cents,
            tax_codes: [tax.code]
          }
        }
      }
    end

    let(:plan) { create(:plan, organization:, amount_cents: 500, description: "desc") }
    let(:package_charge) { create(:package_charge, plan:, organization:) }
    let(:other_billable_metric) { create(:billable_metric, organization:) }
    let(:pricing_unit) { create(:pricing_unit, organization:, code: "ETH", short_name: "ETH") }
    let(:applied_pricing_unit) { create(:applied_pricing_unit, pricing_unitable: package_charge, pricing_unit:, organization:) }
    let(:tax) { create(:tax, organization:) }
    let(:override_amount_cents) { 999 }
    let(:override_display_name) { "Overridden Threshold 1" }
    let(:usage_threshold) { create(:usage_threshold, plan:, created_at: 1.day.ago) }

    before do
      subscription
      usage_threshold
      package_charge
      applied_pricing_unit
    end

    include_examples "requires API permission", "subscription", "write"

    it "updates a subscription" do
      subject

      expect(response).to have_http_status(:success)
      subscription = json[:subscription]
      expect(subscription).to include(
        lago_id: Regex::UUID,
        name: "subscription name new",
        subscription_at: "2022-09-05T12:23:12Z"
      )

      expect(subscription[:payment_method][:payment_method_type]).to eq("provider")
      expect(subscription[:payment_method][:payment_method_id]).to eq(nil)
      plan_json = subscription[:plan]
      expect(plan_json).to include(
        lago_id: Regex::UUID,
        name: "Override",
        invoice_display_name: "Override plan",
        created_at: Regex::ISO8601_DATETIME,
        code: a_kind_of(String),
        interval: "monthly",
        description: "This plan is used to test the override functionality",
        amount_cents: 200,
        amount_currency: "USD",
        trial_period: nil,
        pay_in_advance: false,
        bill_charges_monthly: nil,
        bill_fixed_charges_monthly: false,
        customers_count: 0,
        active_subscriptions_count: 0,
        draft_invoices_count: 0,
        parent_id: plan.id,
        pending_deletion: false,
        taxes: [],
        usage_thresholds: []
      )
      expect(plan_json[:applicable_usage_thresholds]).to contain_exactly({
        threshold_display_name: usage_threshold.threshold_display_name,
        amount_cents: usage_threshold.amount_cents,
        recurring: false
      }, {
        threshold_display_name: plan_usage_threshold.threshold_display_name,
        amount_cents: plan_usage_threshold.amount_cents,
        recurring: false
      })
      minimum_commitment = plan_json[:minimum_commitment]
      expect(minimum_commitment).to match(
        {
          invoice_display_name: commitment_invoice_display_name,
          amount_cents: commitment_amount_cents,
          lago_id: Regex::UUID,
          plan_code: a_kind_of(String),
          interval: "monthly",
          created_at: Regex::ISO8601_DATETIME,
          updated_at: Regex::ISO8601_DATETIME,
          taxes: [
            {
              lago_id: Regex::UUID,
              name: "VAT",
              code: a_kind_of(String),
              rate: 20.0,
              description: "French Standard VAT",
              applied_to_organization: false,
              add_ons_count: 0,
              customers_count: 0,
              plans_count: 0,
              charges_count: 0,
              commitments_count: 0,
              created_at: Regex::ISO8601_DATETIME
            }
          ]
        }
      )
      charges = plan_json[:charges]
      expect(charges.length).to eq(1)
      charge = charges.first
      expect(charge).to match(
        {
          lago_id: Regex::UUID,
          lago_billable_metric_id: package_charge.billable_metric.id,
          code: package_charge.code,
          invoice_display_name: "Setup",
          billable_metric_code: package_charge.billable_metric.code,
          created_at: Regex::ISO8601_DATETIME,
          charge_model: "package",
          invoiceable: true,
          regroup_paid_fees: nil,
          pay_in_advance: false,
          prorated: false,
          min_amount_cents: 6000,
          accepts_target_wallet: false,
          properties: {
            amount: "60",
            free_units: 200,
            package_size: 2000
          },
          applied_pricing_unit: {conversion_rate: "2.0", code: pricing_unit.code},
          lago_parent_id: package_charge.id,
          filters: [],
          taxes: [
            {
              lago_id: Regex::UUID,
              name: "VAT",
              code: a_kind_of(String),
              rate: 20.0,
              description: "French Standard VAT",
              applied_to_organization: false,
              add_ons_count: 0,
              customers_count: 0,
              plans_count: 0,
              charges_count: 0,
              commitments_count: 0,
              created_at: Regex::ISO8601_DATETIME
            }
          ]
        }
      )
    end

    context "when updating usage_thresholds" do
      let(:usage_thresholds) do
        [{
          amount_cents: override_amount_cents,
          threshold_display_name: override_display_name
        }]
      end

      context "when usage_thresholds are part of plan_overrides (legacy)" do
        let(:update_params) do
          {
            name: "subscription name new",
            plan_overrides: {
              usage_thresholds:
            }
          }
        end

        it "attaches the usage thresholds to the child plan" do
          subject

          expect(response).to have_http_status(:success)

          subscription = Subscription.find_by(id: json[:subscription][:lago_id])
          expect(subscription.plan.is_child?).to be true
          expect(subscription.plan.usage_thresholds.pluck(:amount_cents, :threshold_display_name)).to eq([[override_amount_cents, override_display_name]])
          expect(subscription.plan.parent.usage_thresholds.count).to eq 2
          expect(subscription.usage_thresholds).to be_empty

          expect(json[:subscription][:plan][:usage_thresholds]).to contain_exactly(
            {
              lago_id: Regex::UUID,
              threshold_display_name: "Overridden Threshold 1",
              amount_cents: 999,
              recurring: false,
              created_at: Regex::ISO8601_DATETIME,
              updated_at: Regex::ISO8601_DATETIME
            }
          )
          expect(json[:subscription][:plan][:applicable_usage_thresholds].count).to eq 2
          expect(json[:subscription][:applicable_usage_thresholds]).to eq(json[:subscription][:plan][:usage_thresholds].map { |t| t.slice(:threshold_display_name, :amount_cents, :recurring) })
        end
      end

      context "when usage_thresholds are part of subscription and has plan_overrides" do
        let(:update_params) do
          {
            name: "subscription name new",
            usage_thresholds:,
            plan_overrides: {
              name: "rename plan to create override"
            }
          }
        end

        it "attaches the usage thresholds to the child plan" do
          subject

          expect(response).to have_http_status(:success)

          subscription = Subscription.find_by(id: json[:subscription][:lago_id])
          expect(subscription.plan.is_child?).to be true
          expect(subscription.plan.usage_thresholds).to be_empty
          expect(subscription.plan.parent.usage_thresholds.count).to eq 2
          expect(subscription.usage_thresholds.pluck(:amount_cents, :threshold_display_name)).to eq([[override_amount_cents, override_display_name]])

          expect(json[:subscription][:plan][:usage_thresholds]).to be_empty
          expect(json[:subscription][:plan][:applicable_usage_thresholds].count).to eq 2
          expect(json[:subscription][:applicable_usage_thresholds]).to contain_exactly(
            threshold_display_name: "Overridden Threshold 1",
            amount_cents: 999,
            recurring: false
          )
        end
      end

      context "when usage_thresholds are part of subscription without any plan_overrides" do
        let(:update_params) do
          {
            name: "subscription name new",
            usage_thresholds:
          }
        end

        it "attaches the usage thresholds to the child plan" do
          subject

          expect(response).to have_http_status(:success)

          subscription = Subscription.find_by(id: json[:subscription][:lago_id])
          expect(subscription.plan.is_parent?).to be true
          expect(subscription.plan.usage_thresholds.count).to eq 2
          expect(subscription.usage_thresholds.pluck(:amount_cents, :threshold_display_name)).to eq([[override_amount_cents, override_display_name]])

          expect(json[:subscription][:plan][:usage_thresholds].count).to eq 2
          expect(json[:subscription][:plan][:applicable_usage_thresholds].count).to eq 2
          expect(json[:subscription][:applicable_usage_thresholds]).to contain_exactly(
            threshold_display_name: "Overridden Threshold 1",
            amount_cents: 999,
            recurring: false
          )
        end
      end

      context "when only usage_thresholds are passed without any other parameters" do
        let(:update_params) { {usage_thresholds:} }

        it "updates the usage thresholds without requiring other parameters" do
          subject

          expect(response).to have_http_status(:success)
          expect(json[:subscription][:applicable_usage_thresholds]).to contain_exactly(
            threshold_display_name: override_display_name,
            amount_cents: override_amount_cents,
            recurring: false
          )
        end
      end
    end

    context "when the plan has already been overriden" do
      let(:update_params) do
        {
          name: "subscription name new",
          subscription_at: "2022-09-05T12:23:12Z",
          plan_overrides: {
            name: "Override",
            invoice_display_name: "Override plan",
            interval: "monthly",
            description: "This plan is used to test the override functionality",
            amount_cents: 400,
            amount_currency: "USD",
            charges: [
              {
                billable_metric_id: overriden_package_charge.billable_metric.id,
                charge_model: "package",
                id: overriden_package_charge.id,
                invoice_display_name: "Setup",
                invoiceable: true,
                min_amount_cents: 6000,
                properties: {amount: "60", free_units: 200, package_size: 2000},
                tax_codes: [tax.code]
              },
              {
                applied_pricing_unit: {code: pricing_unit.code, conversion_rate: "40"},
                billable_metric_id: other_billable_metric.id,
                charge_model: "package",
                code: "new_charge_code",
                invoice_display_name: "Setup 2",
                invoiceable: true,
                min_amount_cents: 6000,
                properties: {amount: "60", free_units: 200, package_size: 2000},
                tax_codes: [tax.code]
              }
            ],
            fixed_charges: [
              {
                id: overriden_fixed_charge.id,
                units: 90,
                invoice_display_name: "Overridden Fixed Charge",
                properties: {amount: "20"},
                tax_codes: [tax.code],
                apply_units_immediately: true
              }
            ],
            minimum_commitment: {
              invoice_display_name: commitment_invoice_display_name,
              amount_cents: commitment_amount_cents,
              tax_codes: [tax.code]
            },
            usage_thresholds: [
              {
                id: overriden_usage_threshold.id,
                amount_cents: override_amount_cents
              },
              {
                amount_cents: 4000,
                threshold_display_name: "Threshold 2"
              }
            ]
          }
        }
      end

      let(:subscription) { create(:subscription, :pending, customer:, plan: overriden_plan) }
      let(:overriden_plan) { create(:plan, organization:, parent_id: plan.id) }
      let(:billable_metric) { create(:billable_metric, organization:) }
      let(:overriden_package_charge) { create(:package_charge, plan: overriden_plan, organization:, billable_metric:) }
      let(:overriden_fixed_charge) { create(:fixed_charge, plan: overriden_plan, organization:, parent_id: fixed_charge) }
      let(:fixed_charge) { create(:fixed_charge, plan:, organization:) }
      let(:commitment) { create(:commitment, plan: overriden_plan) }
      let(:overriden_usage_threshold) { create(:usage_threshold, plan: overriden_plan, threshold_display_name: "Threshold 1", amount_cents: 1000) }
      let(:other_billable_metric) { create(:billable_metric, organization:) }

      before do
        overriden_package_charge
        overriden_fixed_charge
        overriden_usage_threshold
        commitment
        other_billable_metric
      end

      context "when progressive billing premium integration is present" do
        before do
          organization.update!(premium_integrations: ["progressive_billing"])
        end

        it "updates a subscription" do
          subject

          expect(response).to have_http_status(:success)
          subscription = json[:subscription]
          expect(subscription).to include(
            lago_id: Regex::UUID,
            name: "subscription name new",
            subscription_at: "2022-09-05T12:23:12Z"
          )
          plan_json = subscription[:plan]
          expect(plan_json).to include(
            lago_id: Regex::UUID,
            name: "Override",
            invoice_display_name: "Override plan",
            created_at: Regex::ISO8601_DATETIME,
            code: a_kind_of(String),
            interval: "monthly",
            description: "This plan is used to test the override functionality",
            amount_cents: 400,
            amount_currency: "EUR",
            trial_period: nil,
            pay_in_advance: false,
            bill_charges_monthly: nil,
            bill_fixed_charges_monthly: false,
            customers_count: 0,
            active_subscriptions_count: 0,
            draft_invoices_count: 0,
            parent_id: plan.id,
            pending_deletion: false,
            taxes: []
          )
          minimum_commitment = plan_json[:minimum_commitment]
          expect(minimum_commitment).to match(
            {
              invoice_display_name: commitment_invoice_display_name,
              amount_cents: commitment_amount_cents,
              lago_id: Regex::UUID,
              plan_code: a_kind_of(String),
              interval: "monthly",
              created_at: Regex::ISO8601_DATETIME,
              updated_at: Regex::ISO8601_DATETIME,
              taxes: [
                {
                  lago_id: Regex::UUID,
                  name: "VAT",
                  code: a_kind_of(String),
                  rate: 20.0,
                  description: "French Standard VAT",
                  applied_to_organization: false,
                  add_ons_count: 0,
                  customers_count: 0,
                  plans_count: 0,
                  charges_count: 0,
                  commitments_count: 0,
                  created_at: Regex::ISO8601_DATETIME
                }
              ]
            }
          )
          charges = plan_json[:charges].sort_by { |charge| charge[:invoice_display_name] }
          expect(charges.length).to eq(2)

          first_charge = charges.first
          second_charge = charges.second
          expect(first_charge).to match(
            {
              lago_id: Regex::UUID,
              lago_billable_metric_id: overriden_package_charge.billable_metric.id,
              code: overriden_package_charge.code,
              invoice_display_name: "Setup",
              billable_metric_code: overriden_package_charge.billable_metric.code,
              created_at: Regex::ISO8601_DATETIME,
              charge_model: "package",
              invoiceable: true,
              regroup_paid_fees: nil,
              pay_in_advance: false,
              prorated: false,
              min_amount_cents: 0,
              accepts_target_wallet: false,
              properties: {amount: "60", free_units: 200, package_size: 2000},
              applied_pricing_unit: nil,
              lago_parent_id: nil,
              filters: [],
              taxes: [
                {
                  lago_id: Regex::UUID,
                  name: "VAT",
                  code: a_kind_of(String),
                  rate: 20.0,
                  description: "French Standard VAT",
                  applied_to_organization: false,
                  add_ons_count: 0,
                  customers_count: 0,
                  plans_count: 0,
                  charges_count: 0,
                  commitments_count: 0,
                  created_at: Regex::ISO8601_DATETIME
                }
              ]
            }
          )
          expect(second_charge).to match(
            {
              lago_id: Regex::UUID,
              lago_billable_metric_id: other_billable_metric.id,
              code: "new_charge_code",
              invoice_display_name: "Setup 2",
              billable_metric_code: other_billable_metric.code,
              created_at: Regex::ISO8601_DATETIME,
              charge_model: "package",
              invoiceable: true,
              regroup_paid_fees: nil,
              pay_in_advance: false,
              prorated: false,
              min_amount_cents: 6000,
              applied_pricing_unit: {conversion_rate: "40.0", code: pricing_unit.code},
              accepts_target_wallet: false,
              properties: {amount: "60", free_units: 200, package_size: 2000},
              lago_parent_id: nil,
              filters: [],
              taxes: [
                {
                  lago_id: Regex::UUID,
                  name: "VAT",
                  code: a_kind_of(String),
                  rate: 20.0,
                  description: "French Standard VAT",
                  applied_to_organization: false,
                  add_ons_count: 0,
                  customers_count: 0,
                  plans_count: 0,
                  charges_count: 0,
                  commitments_count: 0,
                  created_at: Regex::ISO8601_DATETIME
                }
              ]
            }
          )

          usage_thresholds = plan_json[:usage_thresholds]
          expect(usage_thresholds.length).to eq(2)
          expect(usage_thresholds.first).to match(
            {
              # previous threshold was removed and a new one created
              # so ID as changed and threshold was lost
              lago_id: Regex::UUID,
              threshold_display_name: nil,
              amount_cents: 999,
              recurring: false,
              created_at: Regex::ISO8601_DATETIME,
              updated_at: Regex::ISO8601_DATETIME
            }
          )
          expect(usage_thresholds.second).to match(
            {
              lago_id: Regex::UUID,
              threshold_display_name: "Threshold 2",
              amount_cents: 4000,
              recurring: false,
              created_at: Regex::ISO8601_DATETIME,
              updated_at: Regex::ISO8601_DATETIME
            }
          )
        end
      end

      it "creates fixed charge events for the subscription" do
        subject

        subscription = Subscription.find_by(external_id: json[:subscription][:external_id])
        expect(subscription.fixed_charge_events.count).to eq(1)

        expect(subscription.fixed_charge_events.pluck(:fixed_charge_id, :timestamp, :units))
          .to contain_exactly(
            [overriden_fixed_charge.id, be_within(1.second).of(subscription.started_at), 90]
          )
      end
    end

    context "with not existing subscription" do
      let(:external_id) { SecureRandom.uuid }

      it "returns an not found error" do
        subject
        expect(response).to have_http_status(:not_found)
      end
    end

    context "when update invoice_custom_section is sent" do
      context "with skip" do
        let(:update_params) do
          {
            invoice_custom_section: {
              skip_invoice_custom_sections: true
            }
          }
        end

        before { subscription.update(skip_invoice_custom_sections: false) }

        it "updates skip_invoice_custom_sections" do
          subject

          subscription = Subscription.find_by(external_id: json[:subscription][:external_id])
          expect(subscription.skip_invoice_custom_sections).to be_truthy
        end
      end

      context "without skipping" do
        context "with sections" do
          let(:update_params) do
            {
              invoice_custom_section: {
                skip_invoice_custom_sections: false,
                invoice_custom_section_codes: [section_1.code]
              }
            }
          end

          before { subscription.update(skip_invoice_custom_sections: true) }

          it "updates skip_invoice_custom_sections" do
            subject

            subscription = Subscription.find_by(external_id: json[:subscription][:external_id])
            expect(subscription.skip_invoice_custom_sections).to be_falsey
            expect(subscription.applied_invoice_custom_sections.count).to eq(1)
            expect(subscription.applied_invoice_custom_sections.pluck(:invoice_custom_section_id)).to include(section_1.id)
          end
        end
      end
    end

    context "when updating progressive_billing_disabled" do
      let(:update_params) { {progressive_billing_disabled: true} }
      let(:subscription) { create(:subscription, customer:, plan:) }

      it "updates progressive_billing_disabled" do
        subject

        expect(response).to have_http_status(:success)
        expect(json[:subscription][:progressive_billing_disabled]).to be(true)

        subscription = Subscription.find_by(external_id: json[:subscription][:external_id])
        expect(subscription.progressive_billing_disabled).to be(true)
      end
    end

    context "when updating consolidate_invoice" do
      let(:update_params) { {consolidate_invoice: false} }
      let(:subscription) { create(:subscription, customer:, plan:) }

      it "updates consolidate_invoice" do
        subject

        expect(response).to have_http_status(:success)
        expect(json[:subscription][:consolidate_invoice]).to be(false)

        subscription = Subscription.find_by(external_id: json[:subscription][:external_id])
        expect(subscription.consolidate_invoice).to be(false)
      end
    end

    context "with multuple subscriptions" do
      let(:update_params) do
        {name: "subscription name new"}
      end
      let(:active_plan) { create(:plan, organization:, amount_cents: 5000, description: "desc") }
      let!(:active_subscription) do
        create(:subscription, external_id: subscription.external_id, customer:, plan:)
      end

      it "updates the active subscription" do
        subject

        expect(response).to have_http_status(:success)
        expect(json[:subscription][:lago_id]).to eq(active_subscription.id)
        expect(json[:subscription][:name]).to eq("subscription name new")
      end

      context "with pending params" do
        let(:params) { {subscription: update_params, status: "pending"} }

        it "updates the pending subscription" do
          subject
          subscription.reload

          expect(response).to have_http_status(:success)
          expect(json[:subscription][:lago_id]).to eq(subscription.id)
          expect(json[:subscription][:name]).to eq("subscription name new")
          expect(subscription.status).to eq("pending")
        end
      end
    end

    context "with applied_invoice_custom_sections in response" do
      let(:update_params) { {name: "updated"} }
      let(:subscription) { create(:subscription, customer:, plan:) }

      before { create(:subscription_applied_invoice_custom_section, subscription:) }

      it "includes applied_invoice_custom_sections as an array in the serialized response" do
        subject

        expect(response).to have_http_status(:success)
        expect(json[:subscription][:applied_invoice_custom_sections]).to be_an(Array)
        expect(json[:subscription][:applied_invoice_custom_sections].count).to eq(1)
      end
    end

    context "with activation_rules" do
      let(:subscription) { create(:subscription, :pending, customer:, plan:, subscription_at: Time.current + 3.days) }
      let(:update_params) { {activation_rules: [{type: "payment", timeout_hours: 24}]} }

      before { create(:payment_method, customer:, organization:) }

      it "persists and returns activation rules" do
        subject

        expect(response).to have_http_status(:success)
        expect(json[:subscription][:activation_rules].size).to eq(1)
        expect(json[:subscription][:activation_rules].first).to include(
          lago_id: String,
          type: "payment",
          timeout_hours: 24,
          status: "inactive"
        )
      end

      context "when timeout_hours is omitted" do
        let(:update_params) { {activation_rules: [{type: "payment"}]} }

        it "persists rule with default timeout_hours of 0" do
          subject

          expect(response).to have_http_status(:success)
          expect(json[:subscription][:activation_rules].first[:timeout_hours]).to eq(0)
        end
      end

      context "when subscription is active" do
        let(:subscription) { create(:subscription, customer:, plan:) }

        it "returns a validation error" do
          subject

          expect(response).to have_http_status(:unprocessable_content)
          expect(json[:error_details]).to eq({activation_rules: %w[subscription_not_pending]})
        end
      end

      context "when subscription is incomplete" do
        let(:subscription) { create(:subscription, :incomplete, customer:, plan:) }
        let(:update_params) { {name: "new name"} }

        it "returns a method not allowed error" do
          subject

          expect(response).to have_http_status(:method_not_allowed)
          expect(json[:code]).to eq("subscription_incomplete")
        end
      end

      context "when updating billing_entity" do
        let(:subscription) { create(:subscription, customer:, plan:) }
        let(:new_billing_entity) { create(:billing_entity, organization:) }

        context "with multi_entity_billing feature flag enabled" do
          before { organization.update!(feature_flags: ["multi_entity_billing"]) }

          context "with billing_entity_code" do
            let(:update_params) { {billing_entity_code: new_billing_entity.code} }

            it "updates the subscription's billing entity" do
              subject

              expect(response).to have_http_status(:success)
              expect(subscription.reload.billing_entity_id).to eq(new_billing_entity.id)
            end
          end

          context "with billing_entity_id" do
            let(:update_params) { {billing_entity_id: new_billing_entity.id} }

            it "updates the subscription's billing entity" do
              subject

              expect(response).to have_http_status(:success)
              expect(subscription.reload.billing_entity_id).to eq(new_billing_entity.id)
            end
          end

          context "with an unknown billing_entity_code" do
            let(:update_params) { {billing_entity_code: "does-not-exist"} }

            it "returns a not found error" do
              subject

              expect(response).to be_not_found_error("billing_entity")
            end
          end
        end

        context "with multi_entity_billing feature flag disabled" do
          let(:update_params) { {billing_entity_code: new_billing_entity.code} }

          it "silently ignores billing_entity_code and returns success" do
            subject

            expect(response).to have_http_status(:success)
            expect(subscription.reload.billing_entity_id).to be_nil
          end
        end
      end
    end
  end

  describe "GET /api/v1/subscriptions/:external_id" do
    subject do
      get_with_token(organization, "/api/v1/subscriptions/#{external_id}", params)
    end

    let(:params) { {} }
    let(:subscription) { create(:subscription, customer:, plan:) }
    let(:external_id) { subscription.external_id }

    include_examples "requires API permission", "subscription", "read"

    it "returns a subscription" do
      create(:entitlement, :subscription, organization:, subscription:)
      usage_threshold = create(:usage_threshold, :for_subscription, subscription:)
      subject

      expect(response).to have_http_status(:success)
      expect(json[:subscription]).to include(
        lago_id: subscription.id,
        external_id: subscription.external_id
      )
      expect(json[:subscription][:entitlements]).to contain_exactly({
        code: start_with("feature_"),
        name: "Feature Name",
        description: "Feature Description",
        privileges: [],
        overrides: {}
      })
      expect(json[:subscription][:applicable_usage_thresholds]).to contain_exactly(
        {
          amount_cents: 100,
          threshold_display_name: usage_threshold.threshold_display_name,
          recurring: false
        }
      )
      expect(json[:subscription][:plan][:applicable_usage_thresholds]).to contain_exactly(
        {
          amount_cents: 10_00,
          threshold_display_name: "Init",
          recurring: false
        }
      )
    end

    context "when subscription does not exist" do
      let(:external_id) { SecureRandom.uuid }

      it "returns not found" do
        subject
        expect(response).to have_http_status(:not_found)
      end
    end

    context "when status is given" do
      let(:params) { {status: "pending"} }

      let!(:matching_subscription) do
        create(:subscription, customer:, plan:, status: :pending, external_id: subscription.external_id)
      end

      it "returns the subscription with the given status" do
        subject

        expect(response).to have_http_status(:success)
        expect(json[:subscription]).to include(
          lago_id: matching_subscription.id,
          external_id: matching_subscription.external_id
        )
      end
    end

    context "with N+1 query detection", bullet: {n_plus_one_query: true, unused_eager_loading: false} do
      before do
        prev = create(:subscription, customer:, plan: create(:plan, organization:), status: :terminated)
        nxt = create(:subscription, customer:, plan: create(:plan, organization:), status: :pending)
        subscription.update!(previous_subscription: prev, next_subscriptions: [nxt])
      end

      it "does not trigger N+1 queries when serializing associations" do
        subject

        expect(response).to have_http_status(:success)
        expect(json[:subscription][:previous_plan_code]).to be_present
        expect(json[:subscription][:next_plan_code]).to be_present
      end
    end

    context "when there are multiple terminated subscriptions" do
      let(:subscription) do
        create(:subscription, customer:, plan:, status: :terminated, terminated_at: 10.days.ago)
      end

      let(:matching_subscription) do
        create(
          :subscription,
          customer:,
          plan:,
          external_id: subscription.external_id,
          terminated_at: 5.days.ago,
          status: :terminated
        )
      end

      let(:params) { {status: "terminated"} }

      before do
        matching_subscription
      end

      it "returns the latest terminated subscription" do
        subject

        expect(response).to have_http_status(:success)
        expect(json[:subscription]).to include(
          lago_id: matching_subscription.id,
          external_id: matching_subscription.external_id
        )
      end
    end

    context "with applied_invoice_custom_sections in response" do
      before { create(:subscription_applied_invoice_custom_section, subscription:) }

      it "includes applied_invoice_custom_sections as an array in the serialized response" do
        subject

        expect(response).to have_http_status(:success)
        expect(json[:subscription][:applied_invoice_custom_sections]).to be_an(Array)
        expect(json[:subscription][:applied_invoice_custom_sections].count).to eq(1)
      end
    end
  end

  describe "GET /api/v1/subscriptions" do
    subject { get_with_token(organization, "/api/v1/subscriptions", params) }

    it_behaves_like "a subscription index endpoint" do
      context "when external customer id is given" do
        let!(:subscription_2) { create(:subscription, customer: customer_2, organization:, plan:) }
        let(:customer_2) { create(:customer, organization:) }

        let(:params) { {external_customer_id: customer_2.external_id} }

        it "returns subscriptions" do
          subject

          expect(response).to have_http_status(:success)
          expect(json[:subscriptions].count).to eq(1)
          expect(json[:subscriptions].first[:lago_id]).to eq(subscription_2.id)
        end
      end
    end
  end
end
