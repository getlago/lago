# frozen_string_literal: true

require "rails_helper"

RSpec.describe Wallets::CreateService do
  subject(:create_service) { described_class.new(params:) }

  let(:membership) { create(:membership) }
  let(:organization) { membership.organization }
  let(:customer) { create(:customer, organization:, external_id: "foobar", currency: customer_currency) }
  let(:customer_currency) { "EUR" }

  describe "#call" do
    let(:paid_credits) { "1.00" }
    let(:granted_credits) { "0.00" }
    let(:expiration_at) { (Time.current + 1.year).iso8601 }
    let(:ignore_paid_top_up_limits_on_creation) { nil }

    let(:params) do
      {
        name: "New Wallet",
        priority: 5,
        customer:,
        organization_id: organization.id,
        currency: "EUR",
        rate_amount: "5.00",
        expiration_at:,
        paid_credits:,
        granted_credits:,
        paid_top_up_min_amount_cents: 1_00,
        paid_top_up_max_amount_cents: 1_000_00,
        ignore_paid_top_up_limits_on_creation:
      }
    end

    let(:service_result) { create_service.call }

    it "creates a wallet" do
      expect { service_result }.to change(Wallet, :count).by(1)

      expect(service_result).to be_success

      wallet = service_result.wallet
      expect(wallet.customer_id).to eq(customer.id)
      expect(wallet.name).to eq("New Wallet")
      expect(wallet.priority).to eq(5)
      expect(wallet.currency).to eq("EUR")
      expect(wallet.rate_amount).to eq(5.0)
      expect(wallet.expiration_at.iso8601).to eq(expiration_at)
      expect(wallet.recurring_transaction_rules.count).to eq(0)
      expect(wallet.invoice_requires_successful_payment).to eq(false)
      expect(wallet.paid_top_up_min_amount_cents).to eq(1_00)
      expect(wallet.paid_top_up_max_amount_cents).to eq(1_000_00)
    end

    it "sends `wallet.created` webhook" do
      expect { service_result }.to have_enqueued_job_after_commit(SendWebhookJob).with("wallet.created", Wallet)
    end

    it "produces an activity log" do
      wallet = described_class.call(params:).wallet

      expect(Utils::ActivityLog).to have_produced("wallet.created").after_commit.with(wallet)
    end

    it "flags the customer for ongoing balance refresh" do
      expect { service_result }.to change { customer.reload.awaiting_wallet_refresh }.from(false).to(true)
    end

    it "enqueues the WalletTransaction::CreateJob" do
      expect { service_result }.to have_enqueued_job_after_commit(WalletTransactions::CreateJob).with({
        organization_id: organization.id,
        params: {
          wallet_id: Regex::UUID,
          paid_credits: paid_credits,
          granted_credits: granted_credits,
          source: :manual,
          metadata: nil,
          name: nil,
          priority: nil,
          ignore_paid_top_up_limits: ignore_paid_top_up_limits_on_creation
        }
      })
    end

    [
      {ctx: "when one of the credits is zero", paid_credits: "10.00", granted_credits: "0.00", schedules_top_up: true},
      {ctx: "when one of the credits is zero", paid_credits: "10.00", granted_credits: nil, schedules_top_up: true},
      {ctx: "when granted_credits and paid_credits are zero", paid_credits: "0.00", granted_credits: "0.00", schedules_top_up: false},
      {ctx: "when granted_credits and paid_credits are nil", paid_credits: nil, granted_credits: nil, schedules_top_up: false},
      {ctx: "when granted_credits and paid_credits are nil or zero", paid_credits: nil, granted_credits: "0.00", schedules_top_up: false}
    ].each do |test_case|
      context test_case[:ctx] do
        let(:paid_credits) { test_case[:paid_credits] }
        let(:granted_credits) { test_case[:granted_credits] }

        it "creates a wallet #{test_case[:schedules_top_up] ? "with" : "without"} initial top-up" do
          result = nil

          if test_case[:schedules_top_up]
            expect { result = create_service.call }.to have_enqueued_job(WalletTransactions::CreateJob).with(
              organization_id: organization.id,
              params: hash_including(
                paid_credits: paid_credits,
                granted_credits: granted_credits
              )
            )
          else
            expect { result = create_service.call }.not_to have_enqueued_job(WalletTransactions::CreateJob)
          end

          expect(Wallet.count).to eq(1)

          wallet = result.wallet
          expect(wallet.customer_id).to eq(customer.id)
          expect(wallet.name).to eq("New Wallet")
          expect(wallet.priority).to eq(5)
          expect(wallet.currency).to eq("EUR")
          expect(wallet.rate_amount).to eq(5.0)
          expect(wallet.expiration_at.iso8601).to eq(expiration_at)
          expect(wallet.recurring_transaction_rules.count).to eq(0)
        end
      end
    end

    it "creates a traceable wallet" do
      expect(service_result).to be_success
      expect(service_result.wallet.traceable).to eq(true)
    end

    context "when customer has an existing active traceable wallet" do
      before { create(:wallet, customer:, organization:, traceable: true) }

      it "creates a traceable wallet" do
        expect(service_result).to be_success
        expect(service_result.wallet.traceable).to eq(true)
      end
    end

    context "when customer has an existing active non-traceable wallet" do
      before { create(:wallet, customer:, organization:, traceable: false) }

      it "creates a non-traceable wallet" do
        expect(service_result).to be_success
        expect(service_result.wallet.traceable).to eq(false)
      end
    end

    context "when customer has an existing terminated non-traceable wallet" do
      before { create(:wallet, customer:, organization:, traceable: false, status: :terminated) }

      it "creates a traceable wallet" do
        expect(service_result).to be_success
        expect(service_result.wallet.traceable).to eq(true)
      end
    end

    context "with validation error" do
      let(:paid_credits) { "-15.00" }

      it "returns an error" do
        expect(service_result).not_to be_success
        expect(service_result.error.messages[:paid_credits]).to eq(["invalid_paid_credits", "invalid_amount"])
      end
    end

    context "when the initial credits round to zero monetary value" do
      let(:params) do
        {
          name: "New Wallet",
          customer:,
          organization_id: organization.id,
          currency: "EUR",
          rate_amount: "0.01",
          granted_credits: "0.4"
        }
      end

      it "does not create the wallet and returns a validation error" do
        expect { service_result }.not_to change(Wallet, :count)
        expect(service_result).not_to be_success
        expect(service_result.error).to be_a(BaseService::ValidationFailure)
        expect(service_result.error.messages[:granted_credits]).to eq(["amount_rounds_to_zero"])
      end
    end

    context "when customer has reached the wallet limit" do
      before do
        create_list(:wallet, Wallets::ValidateService::MAXIMUM_WALLETS_PER_CUSTOMER, customer:, organization:, status: :active)
      end

      it "returns an error" do
        expect { service_result }.not_to change(Wallet, :count)
        expect(service_result).not_to be_success
        expect(service_result.error.messages[:customer]).to eq(["wallet_limit_reached"])
      end
    end

    context "when paid_credits is above the maximum" do
      let(:paid_credits) { "1002.0" }

      it "returns an error" do
        expect { service_result }.not_to change(organization.wallets, :count)
        expect(service_result).not_to be_success
        expect(service_result.error.messages[:paid_credits]).to eq(["amount_above_maximum"])
      end
    end

    context "when paid_credits is above the maximum and ignore validation flag passed" do
      let(:paid_credits) { "1002.0" }
      let(:ignore_paid_top_up_limits_on_creation) { "true" }

      it "returns an error" do
        perform_enqueued_jobs(only: WalletTransactions::CreateJob) do
          expect { service_result }.to change(organization.wallets, :count)
          expect(service_result).to be_success
          transaction = service_result.wallet.wallet_transactions.first
          expect(transaction).to have_attributes(credit_amount: 1002.00)
        end
      end
    end

    context "when priority is out of bounds" do
      let(:params) do
        {
          name: "New Wallet",
          customer:,
          organization_id: organization.id,
          currency: "EUR",
          rate_amount: "1.00",
          priority: 55
        }
      end

      it "defaults to 50" do
        expect(service_result).not_to be_success
        expect(service_result.error.messages[:priority]).to eq(["value_is_invalid"])
      end
    end

    context "when priority is not set" do
      let(:params) do
        {
          name: "New Wallet",
          customer:,
          organization_id: organization.id,
          currency: "EUR",
          rate_amount: "1.00"
        }
      end

      it "defaults to 50" do
        expect(service_result).to be_success

        wallet = service_result.wallet
        expect(wallet.priority).to eq(50)
      end
    end

    context "when priority is nil" do
      let(:params) do
        {
          name: "New Wallet",
          customer:,
          organization_id: organization.id,
          currency: "EUR",
          rate_amount: "1.00",
          priority: nil
        }
      end

      it "defaults to 50" do
        expect(service_result).to be_success

        wallet = service_result.wallet
        expect(wallet.priority).to eq(50)
      end
    end

    context "when invoice_requires_successful_payment is set" do
      let(:params) do
        {
          name: "New Wallet",
          customer:,
          organization_id: organization.id,
          currency: "EUR",
          rate_amount: "1.00",
          paid_credits:,
          invoice_requires_successful_payment:
        }
      end
      let(:invoice_requires_successful_payment) { true }

      it "follows the value" do
        expect { service_result }.to change(Wallet, :count).by(1)

        expect(service_result).to be_success

        wallet = service_result.wallet
        expect(wallet.invoice_requires_successful_payment).to eq(true)
      end

      context "when invoice_requires_successful_payment is null" do
        let(:invoice_requires_successful_payment) { nil }

        it "defaults to false" do
          expect { service_result }.to change(Wallet, :count).by(1)

          expect(service_result).to be_success

          wallet = service_result.wallet
          expect(wallet.invoice_requires_successful_payment).to eq(false)
        end
      end
    end

    context "when customer does not have a currency" do
      let(:customer_currency) { nil }

      it "applies the currency to the customer" do
        service_result
        expect(customer.reload.currency).to eq("EUR")
      end

      it "sets the wallet currency from customer" do
        wallet = service_result.wallet
        expect(wallet.currency).to eq(customer.reload.currency)
      end

      context "when no currency is provided" do
        let(:params) do
          {
            name: "New Wallet",
            customer:,
            organization_id: organization.id,
            currency: nil,
            rate_amount: "1.00",
            expiration_at:,
            paid_credits:,
            granted_credits:
          }
        end

        it "returns an error" do
          expect(service_result).not_to be_success
          expect(service_result.error.messages[:currency]).to eq(["value_is_invalid"])
        end
      end
    end

    context "when customer already has a different currency" do
      let(:customer_currency) { "USD" }

      it "returns a currency mismatch error" do
        expect(service_result).not_to be_success
        expect(service_result.error.messages[:currency]).to eq(["currencies_does_not_match"])
      end

      it "does not update the customer currency" do
        service_result
        expect(customer.reload.currency).to eq("USD")
      end
    end

    context "when customer already has the same currency" do
      let(:customer_currency) { "EUR" }

      it "creates the wallet successfully" do
        expect(service_result).to be_success

        wallet = service_result.wallet
        expect(wallet.currency).to eq("EUR")
      end

      it "does not change the customer currency" do
        service_result
        expect(customer.reload.currency).to eq("EUR")
      end
    end

    context "when multi currency is enabled" do
      before { organization.update!(feature_flags: ["multi_currency"]) }

      context "when customer does not have a currency" do
        let(:customer_currency) { nil }

        it "applies the currency to the customer" do
          service_result
          expect(customer.reload.currency).to eq("EUR")
        end

        it "sets the wallet currency from params" do
          wallet = service_result.wallet
          expect(wallet.currency).to eq("EUR")
        end
      end

      context "when customer already has a different currency" do
        let(:customer_currency) { "USD" }

        it "does not update the customer currency" do
          service_result
          expect(customer.reload.currency).to eq("USD")
        end

        it "sets the wallet currency from params" do
          wallet = service_result.wallet
          expect(wallet.currency).to eq("EUR")
        end
      end

      context "when customer already has the same currency" do
        let(:customer_currency) { "EUR" }

        it "creates the wallet successfully" do
          expect(service_result).to be_success

          wallet = service_result.wallet
          expect(wallet.currency).to eq("EUR")
        end
      end

      context "when currency param is nil and customer has a currency" do
        let(:customer_currency) { "USD" }
        let(:params) do
          {
            name: "New Wallet",
            customer:,
            organization_id: organization.id,
            currency: nil,
            rate_amount: "1.00",
            expiration_at:,
            paid_credits: "0.00",
            granted_credits: "0.00"
          }
        end

        it "falls back to the customer currency" do
          expect(service_result).to be_success

          wallet = service_result.wallet
          expect(wallet.currency).to eq("USD")
        end
      end
    end

    context "when wallet have transaction metadata" do
      let(:params) do
        {
          name: "New Wallet",
          customer:,
          organization_id: organization.id,
          currency: "EUR",
          rate_amount: "1.00",
          expiration_at:,
          paid_credits: "10",
          granted_credits: "10",
          transaction_metadata: [{"key" => "valid_value", "value" => "also_valid"}]
        }
      end

      it "enqueues the job with correct metadata" do
        expect { service_result }.to have_enqueued_job(
          WalletTransactions::CreateJob
        ).with(hash_including(
          params: hash_including(metadata: params[:transaction_metadata])
        ))
      end
    end

    context "when transaction_name is provided" do
      let(:params) do
        {
          name: "New Wallet",
          customer:,
          organization_id: organization.id,
          currency: "EUR",
          rate_amount: "1.00",
          expiration_at:,
          paid_credits:,
          granted_credits:,
          transaction_name: "Custom Transaction Name"
        }
      end

      it "enqueues the wallet transaction job with the transaction name" do
        expect { service_result }.to have_enqueued_job(
          WalletTransactions::CreateJob
        ).with(hash_including(
          params: hash_including(name: "Custom Transaction Name")
        ))
      end
    end

    context "with recurring transaction rules", :premium do
      let(:rules) do
        [
          {
            interval: "monthly",
            method: "target",
            paid_credits: "10.0",
            granted_credits: "5.0",
            target_ongoing_balance: "100.0",
            trigger: "interval"
          }
        ]
      end
      let(:params) do
        {
          name: "New Wallet",
          customer:,
          organization_id: organization.id,
          currency: "EUR",
          rate_amount: "1.00",
          expiration_at:,
          paid_credits:,
          granted_credits:,
          recurring_transaction_rules: rules,
          paid_top_up_max_amount_cents: "5000"
        }
      end

      it "creates a wallet with recurring transaction rules" do
        expect { service_result }.to change(Wallet, :count).by(1)

        expect(service_result).to be_success
        wallet = service_result.wallet
        expect(wallet.name).to eq("New Wallet")
        expect(wallet.reload.recurring_transaction_rules.count).to eq(1)
      end

      context "when recurring transaction rule has transaction_name" do
        let(:rules) do
          [
            {
              interval: "monthly",
              method: "target",
              paid_credits: "10.0",
              granted_credits: "5.0",
              target_ongoing_balance: "100.0",
              trigger: "interval",
              transaction_name: "Custom Top-up"
            }
          ]
        end

        it "creates a recurring rule with transaction_name" do
          expect { service_result }.to change(Wallet, :count).by(1)

          wallet = service_result.wallet
          expect(wallet.reload.recurring_transaction_rules.first.transaction_name).to eq("Custom Top-up")
        end
      end

      context "when number of rules is incorrect" do
        let(:rules) do
          [
            {
              trigger: "interval",
              interval: "monthly"
            },
            {
              trigger: "threshold",
              threshold_credits: "1.0"
            }
          ]
        end

        it "returns an error" do
          expect(service_result).not_to be_success
          expect(service_result.error.messages[:recurring_transaction_rules])
            .to eq(["invalid_number_of_recurring_rules"])
        end
      end

      context "when trigger is invalid" do
        let(:rules) do
          [
            {
              trigger: "invalid",
              interval: "monthly"
            }
          ]
        end

        it "returns an error" do
          expect(service_result).not_to be_success
          expect(service_result.error.messages[:recurring_transaction_rules]).to eq(["invalid_recurring_rule"])
        end
      end

      context "when threshold credits value is invalid" do
        let(:rules) do
          [
            {
              trigger: "threshold",
              threshold_credits: "abc"
            }
          ]
        end

        it "returns an error" do
          expect(service_result).not_to be_success
          expect(service_result.error.messages[:recurring_transaction_rules]).to eq(["invalid_recurring_rule"])
        end
      end

      context "when paid credits exceeds wallet limits" do
        let(:rules) do
          [
            {
              trigger: "interval",
              interval: "monthly",
              paid_credits: "100"
            }
          ]
        end

        it "returns an error" do
          expect(service_result).to be_failure
          expect(service_result.error.messages[:recurring_transaction_rules]).to eq(["invalid_recurring_rule"])
        end
      end
    end

    context "with limitations" do
      let(:limitations) do
        {
          fee_types: %w[charge]
        }
      end
      let(:params) do
        {
          name: "New Wallet",
          customer:,
          organization_id: organization.id,
          currency: "EUR",
          rate_amount: "1.00",
          expiration_at:,
          paid_credits:,
          granted_credits:,
          applies_to: limitations
        }
      end

      it "creates a wallet with correct limitations" do
        expect { service_result }.to change(Wallet, :count).by(1)
        expect(service_result).to be_success

        wallet = service_result.wallet
        expect(wallet.reload.name).to eq("New Wallet")
        expect(wallet.reload.allowed_fee_types).to eq(%w[charge])
      end

      context "when fee limitations are not correct" do
        let(:limitations) do
          {
            fee_types: %w[invalid]
          }
        end

        it "returns an error" do
          expect(service_result).not_to be_success
          expect(service_result.error.messages[:applies_to]).to eq(["invalid_limitations"])
        end
      end

      context "with billable metric limitations in graphql context" do
        let(:billable_metric) { create(:billable_metric, organization:) }
        let(:limitations) do
          {
            billable_metric_ids: [billable_metric.id]
          }
        end

        before { CurrentContext.source = "graphql" }

        it "creates a wallet" do
          expect { service_result }.to change(Wallet, :count).by(1)
          expect(service_result).to be_success
        end

        it "creates a wallet target" do
          expect { create_service.call }
            .to change(WalletTarget, :count).by(1)
        end

        context "with invalid billable metric" do
          let(:limitations) do
            {
              billable_metric_ids: [billable_metric.id, "invalid"]
            }
          end

          it "returns an error" do
            expect(service_result).not_to be_success
            expect(service_result.error.messages[:applies_to]).to eq(["invalid_limitations"])
          end
        end
      end

      context "with billable metric limitations in api context" do
        let(:billable_metric) { create(:billable_metric, organization:) }
        let(:limitations) do
          {
            billable_metric_codes: [billable_metric.code]
          }
        end

        before { CurrentContext.source = "api" }

        it "creates a wallet" do
          expect { service_result }.to change(Wallet, :count).by(1)
          expect(service_result).to be_success
        end

        it "creates a wallet target" do
          expect { create_service.call }
            .to change(WalletTarget, :count).by(1)
        end
      end
    end

    context "with payment method" do
      let(:payment_method) { create(:payment_method, organization:, customer:) }
      let(:payment_method_params) do
        {
          payment_method_id: payment_method.id,
          payment_method_type: "provider"
        }
      end
      let(:params) do
        {
          name: "New Wallet",
          customer:,
          organization_id: organization.id,
          currency: "EUR",
          rate_amount: "1.00",
          expiration_at:,
          paid_credits:,
          granted_credits:,
          payment_method: payment_method_params
        }
      end

      before { payment_method }

      it "creates a wallet with correct payment method" do
        expect { service_result }.to change(Wallet, :count).by(1)
        expect(service_result).to be_success

        wallet = service_result.wallet
        expect(wallet.reload.name).to eq("New Wallet")
        expect(wallet.reload.payment_method_id).to eq(payment_method.id)
        expect(wallet.reload.payment_method_type).to eq("provider")
      end

      context "when payment method id is nil" do
        let(:payment_method_params) do
          {
            payment_method_id: nil,
            payment_method_type: "provider"
          }
        end

        it "successfully creates wallet" do
          expect { service_result }.to change(Wallet, :count).by(1)
          expect(service_result).to be_success

          wallet = service_result.wallet
          expect(wallet.reload.name).to eq("New Wallet")
          expect(wallet.reload.payment_method_id).to eq(nil)
          expect(wallet.reload.payment_method_type).to eq("provider")
        end
      end

      context "when payment method type is not correct" do
        let(:payment_method_params) do
          {
            payment_method_id: payment_method.id,
            payment_method_type: "invalid"
          }
        end

        it "returns an error" do
          expect(service_result).not_to be_success
          expect(service_result.error.messages[:payment_method]).to eq(["invalid_payment_method"])
        end
      end

      context "when payment method id is not correct" do
        let(:payment_method_params) do
          {
            payment_method_id: "123",
            payment_method_type: "provider"
          }
        end

        it "returns an error" do
          expect(service_result).not_to be_success

          expect(service_result.error.messages[:payment_method]).to eq(["invalid_payment_method"])
        end
      end
    end

    context "when organization_id is nil" do
      let(:params) do
        {
          name: "New Wallet",
          customer:,
          organization_id: nil,
          currency: "EUR",
          rate_amount: "1.00",
          expiration_at:,
          paid_credits:,
          granted_credits:
        }
      end

      it "returns an error" do
        expect(service_result).not_to be_success
        expect(service_result.error.messages[:organization_id]).to eq(["blank"])
      end
    end

    context "when organization_id does not match customer's organization_id" do
      let(:other_organization) { create(:organization) }
      let(:params) do
        {
          name: "New Wallet",
          customer:,
          organization_id: other_organization.id,
          currency: "EUR",
          rate_amount: "1.00",
          expiration_at:,
          paid_credits:,
          granted_credits:
        }
      end

      it "returns an error" do
        expect(service_result).not_to be_success
        expect(service_result.error.messages[:organization_id]).to eq(["invalid"])
      end
    end

    context "with metadata" do
      let(:params) do
        {
          name: "New Wallet",
          customer:,
          organization_id: organization.id,
          currency: "EUR",
          rate_amount: "1.00",
          expiration_at:,
          paid_credits:,
          granted_credits:,
          metadata: {"foo" => "bar", "baz" => "qux"}
        }
      end

      it "creates a wallet with metadata" do
        expect { service_result }.to change(Wallet, :count).by(1)
        expect(service_result).to be_success

        wallet = service_result.wallet
        expect(wallet.metadata).to be_present
        expect(wallet.metadata.value).to eq({"foo" => "bar", "baz" => "qux"})
      end
    end

    context "when metadata is nil" do
      let(:params) do
        {
          name: "New Wallet",
          customer:,
          organization_id: organization.id,
          currency: "EUR",
          rate_amount: "1.00",
          expiration_at:,
          paid_credits:,
          granted_credits:,
          metadata: nil
        }
      end

      it "creates a wallet without metadata" do
        expect { service_result }.to change(Wallet, :count).by(1)
        expect(service_result).to be_success

        wallet = service_result.wallet
        expect(wallet.metadata).to be_nil
      end
    end

    context "when code is provided" do
      let(:params) do
        {
          name: "New Wallet",
          code: "custom_code",
          customer:,
          organization_id: organization.id,
          currency: "EUR",
          rate_amount: "1.00",
          paid_credits:,
          granted_credits:
        }
      end

      it "creates a wallet with the provided code" do
        expect { service_result }.to change(Wallet, :count).by(1)
        expect(service_result).to be_success

        wallet = service_result.wallet
        expect(wallet.code).to eq("custom_code")
      end

      context "when code is already taken for the customer" do
        let(:wallet) { create(:wallet, customer:, organization:, code: "existing_code") }
        let(:params) do
          {
            name: "New Wallet",
            code: "existing_code",
            customer:,
            organization_id: organization.id,
            currency: "EUR",
            rate_amount: "1.00",
            paid_credits:,
            granted_credits:
          }
        end

        before { wallet }

        it "returns an error" do
          expect { service_result }.not_to change(Wallet, :count)
          expect(service_result).not_to be_success
          expect(service_result.error.messages[:code]).to eq(["value_already_exist"])
        end

        context "when existing wallet is terminated" do
          let(:wallet) { create(:wallet, customer:, organization:, code: "existing_code", status: "terminated") }

          it "creates the wallet successfully" do
            expect { service_result }.to change(Wallet, :count).by(1)
            expect(service_result).to be_success

            wallet = service_result.wallet
            expect(wallet.code).to eq("existing_code")
          end
        end
      end
    end

    context "when code is not provided but name is" do
      let(:params) do
        {
          name: "My Premium Wallet",
          customer:,
          organization_id: organization.id,
          currency: "EUR",
          rate_amount: "1.00",
          paid_credits:,
          granted_credits:
        }
      end

      it "creates a wallet with code derived from name" do
        expect { service_result }.to change(Wallet, :count).by(1)
        expect(service_result).to be_success

        wallet = service_result.wallet
        expect(wallet.code).to eq("my_premium_wallet")
      end

      context "when name is already taken for the customer" do
        let(:wallet) { create(:wallet, customer:, organization:, name: "Existing Name", code: "existing_name") }

        let(:params) do
          {
            name: "existing name",
            customer:,
            organization_id: organization.id,
            currency: "EUR",
            rate_amount: "1.00",
            paid_credits:,
            granted_credits:
          }
        end

        before { wallet }

        it "creates a wallet with timestamp in the code" do
          expect { service_result }.to change(Wallet, :count).by(1)
          expect(service_result).to be_success

          wallet = service_result.wallet
          expect(wallet.code).to eq("existing_name_#{wallet.created_at.to_i}")
        end

        context "when name is already taken by a terminated wallet" do
          let(:wallet) { create(:wallet, customer:, organization:, name: "Existing Name", code: "existing_name", status: "terminated") }

          it "creates a wallet with code derived from name" do
            expect { service_result }.to change(Wallet, :count).by(1)
            expect(service_result).to be_success

            wallet = service_result.wallet
            expect(wallet.code).to eq("existing_name")
          end
        end
      end
    end

    context "when multi_entity_billing is enabled" do
      let!(:billing_entity) { create(:billing_entity, organization:, code: "be_code") }

      before do
        organization.update!(feature_flags: ["multi_entity_billing"])
      end

      context "when billing_entity_code is provided" do
        let(:params) do
          {
            name: "New Wallet",
            customer:,
            organization_id: organization.id,
            currency: "EUR",
            rate_amount: "1.00",
            paid_credits: "0.00",
            granted_credits: "0.00",
            billing_entity_code: "be_code"
          }
        end

        it "assigns the billing entity to the wallet" do
          expect(service_result).to be_success

          wallet = service_result.wallet
          expect(wallet.billing_entity_id).to eq(billing_entity.id)
        end
      end

      context "when billing_entity_id is provided" do
        let(:params) do
          {
            name: "New Wallet",
            customer:,
            organization_id: organization.id,
            currency: "EUR",
            rate_amount: "1.00",
            paid_credits: "0.00",
            granted_credits: "0.00",
            billing_entity_id: billing_entity.id
          }
        end

        it "assigns the billing entity to the wallet" do
          expect(service_result).to be_success

          wallet = service_result.wallet
          expect(wallet.billing_entity_id).to eq(billing_entity.id)
        end
      end

      context "when neither billing_entity_code nor billing_entity_id is provided" do
        it "creates the wallet without a billing entity" do
          expect(service_result).to be_success

          wallet = service_result.wallet
          expect(wallet.billing_entity_id).to be_nil
        end
      end

      context "when billing_entity_code does not match any entity" do
        let(:params) do
          {
            name: "New Wallet",
            customer:,
            organization_id: organization.id,
            currency: "EUR",
            rate_amount: "1.00",
            paid_credits: "0.00",
            granted_credits: "0.00",
            billing_entity_code: "nonexistent"
          }
        end

        it "returns a not found error" do
          expect(service_result).not_to be_success
          expect(service_result.error).to be_a(BaseService::NotFoundFailure)
          expect(service_result.error.resource).to eq("billing_entity")
        end
      end

      context "when billing_entity_id belongs to another organization" do
        let(:other_organization) { create(:organization) }
        let!(:other_billing_entity) { create(:billing_entity, organization: other_organization) }

        let(:params) do
          {
            name: "New Wallet",
            customer:,
            organization_id: organization.id,
            currency: "EUR",
            rate_amount: "1.00",
            paid_credits: "0.00",
            granted_credits: "0.00",
            billing_entity_id: other_billing_entity.id
          }
        end

        it "returns a not found error" do
          expect(service_result).not_to be_success
          expect(service_result.error).to be_a(BaseService::NotFoundFailure)
          expect(service_result.error.resource).to eq("billing_entity")
        end
      end

      context "when billing_entity_code belongs to another organization" do
        let(:other_organization) { create(:organization) }
        let!(:other_billing_entity) { create(:billing_entity, organization: other_organization, code: "other_org_be") }

        let(:params) do
          {
            name: "New Wallet",
            customer:,
            organization_id: organization.id,
            currency: "EUR",
            rate_amount: "1.00",
            paid_credits: "0.00",
            granted_credits: "0.00",
            billing_entity_code: "other_org_be"
          }
        end

        before { other_billing_entity }

        it "returns a not found error" do
          expect(service_result).not_to be_success
          expect(service_result.error).to be_a(BaseService::NotFoundFailure)
          expect(service_result.error.resource).to eq("billing_entity")
        end
      end

      context "when billing_entity_id does not match any entity" do
        let(:params) do
          {
            name: "New Wallet",
            customer:,
            organization_id: organization.id,
            currency: "EUR",
            rate_amount: "1.00",
            paid_credits: "0.00",
            granted_credits: "0.00",
            billing_entity_id: SecureRandom.uuid
          }
        end

        it "returns a not found error" do
          expect(service_result).not_to be_success
          expect(service_result.error).to be_a(BaseService::NotFoundFailure)
          expect(service_result.error.resource).to eq("billing_entity")
        end
      end

      context "when both billing_entity_id and billing_entity_code are provided" do
        let!(:other_billing_entity) { create(:billing_entity, organization:, code: "other_be") }

        let(:params) do
          {
            name: "New Wallet",
            customer:,
            organization_id: organization.id,
            currency: "EUR",
            rate_amount: "1.00",
            paid_credits: "0.00",
            granted_credits: "0.00",
            billing_entity_id: billing_entity.id,
            billing_entity_code: other_billing_entity.code
          }
        end

        it "billing_entity_id takes precedence" do
          expect(service_result).to be_success

          wallet = service_result.wallet
          expect(wallet.billing_entity_id).to eq(billing_entity.id)
        end
      end
    end

    context "when multi_entity_billing is not enabled" do
      let(:billing_entity) { create(:billing_entity, organization:, code: "be_code") }

      let(:params) do
        {
          name: "New Wallet",
          customer:,
          organization_id: organization.id,
          currency: "EUR",
          rate_amount: "1.00",
          paid_credits: "0.00",
          granted_credits: "0.00",
          billing_entity_code: "be_code"
        }
      end

      before { billing_entity }

      it "does not assign the billing entity even if code is provided" do
        expect(service_result).to be_success

        wallet = service_result.wallet
        expect(wallet.billing_entity_id).to be_nil
      end
    end

    context "when neither code nor name is provided" do
      let(:params) do
        {
          customer:,
          organization_id: organization.id,
          currency: "EUR",
          rate_amount: "1.00",
          paid_credits:,
          granted_credits:
        }
      end

      it "creates a wallet with default code" do
        expect { service_result }.to change(Wallet, :count).by(1)
        expect(service_result).to be_success

        wallet = service_result.wallet
        expect(wallet.code).to eq("default")
      end

      context "when default code is already taken for the customer" do
        before do
          create(:wallet, customer:, organization:, name: nil, code: "default")
        end

        let(:params) do
          {
            customer:,
            organization_id: organization.id,
            currency: "EUR",
            rate_amount: "1.00",
            paid_credits:,
            granted_credits:
          }
        end

        it "creates a wallet with timestamp in the code" do
          Timecop.freeze do
            expect { service_result }.to change(Wallet, :count).by(1)
            expect(service_result).to be_success

            wallet = service_result.wallet
            expect(wallet.code).to eq("default_#{wallet.created_at.to_i}")
          end
        end
      end
    end
  end
end
