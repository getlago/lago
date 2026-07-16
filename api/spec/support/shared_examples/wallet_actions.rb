# frozen_string_literal: true

RSpec.shared_examples "a wallet create endpoint" do
  let(:create_params) do
    {
      external_customer_id: customer.external_id,
      rate_amount: "1",
      name: "Wallet1",
      priority: 12,
      currency: "EUR",
      paid_credits: "10",
      granted_credits: "10",
      expiration_at:,
      invoice_requires_successful_payment: true,
      paid_top_up_min_amount_cents: 5_00,
      paid_top_up_max_amount_cents: 100_00,
      ignore_paid_top_up_limits_on_creation: "true",
      payment_method: {
        payment_method_type: "provider",
        payment_method_id: payment_method.id
      }
    }
  end

  include_examples "requires API permission", "wallet", "write"

  it "creates a wallet" do
    allow(WalletTransactions::CreateFromParamsService).to receive(:call!).and_call_original
    allow(Validators::WalletTransactionAmountLimitsValidator).to receive(:new).and_call_original
    stub_pdf_generation

    subject

    expect(SendWebhookJob).to have_been_enqueued.with("wallet.created", Wallet)

    perform_all_enqueued_jobs(except: [SendWebhookJob])

    expect(response).to have_http_status(:success)

    expect(json[:wallet][:lago_id]).to be_present
    expect(json[:wallet][:name]).to eq(create_params[:name])
    expect(json[:wallet][:priority]).to eq(create_params[:priority])
    expect(json[:wallet][:external_customer_id]).to eq(customer.external_id)
    expect(json[:wallet][:expiration_at]).to eq(expiration_at)
    expect(json[:wallet][:invoice_requires_successful_payment]).to eq(true)
    expect(json[:wallet][:paid_top_up_min_amount_cents]).to eq(5_00)
    expect(json[:wallet][:paid_top_up_max_amount_cents]).to eq(100_00)
    expect(json[:wallet][:payment_method][:payment_method_type]).to eq("provider")
    expect(json[:wallet][:payment_method][:payment_method_id]).to eq(payment_method.id)

    expect(Validators::WalletTransactionAmountLimitsValidator).to have_received(:new).with(
      Wallets::CreateService::Result,
      wallet: Wallet,
      credits_amount: "10",
      ignore_validation: "true"
    )

    expect(WalletTransactions::CreateFromParamsService).to have_received(:call!).with(
      organization: organization,
      params: hash_including(
        wallet_id: json[:wallet][:lago_id],
        paid_credits: "10",
        granted_credits: "10",
        source: :manual
      )
    )
  end

  context "when paid_credit is below the minimum" do
    let(:create_params) do
      {
        external_customer_id: customer.external_id,
        rate_amount: "1",
        paid_credits: "10",
        paid_top_up_min_amount_cents: 30_00
      }
    end

    it "returns a validation error" do
      subject
      expect(response).to have_http_status(:unprocessable_content)
      expect(json[:error_details][:paid_credits]).to eq ["amount_below_minimum"]
    end

    context "when the ignore_paid_top_up_limits_on_creation is set to true" do
      let(:create_params) do
        {
          external_customer_id: customer.external_id,
          rate_amount: "1",
          paid_credits: "10",
          paid_top_up_min_amount_cents: 30_00,
          ignore_paid_top_up_limits_on_creation: "true"
        }
      end

      it "ignores the amount limits" do
        subject
        expect(response).to have_http_status(:success)
        expect(json[:wallet][:lago_id]).to be_present
        expect(json[:wallet][:external_customer_id]).to eq(customer.external_id)
      end
    end
  end

  context "with transaction metadata" do
    let(:create_params) do
      {
        external_customer_id: customer.external_id,
        rate_amount: "1",
        name: "Wallet1",
        currency: "EUR",
        paid_credits: "10",
        granted_credits: "10",
        expiration_at:,
        invoice_requires_successful_payment: true,
        transaction_metadata: [{key: "valid_value", value: "also_valid"}]
      }
    end

    before do
      subject
    end

    it "schedules a WalletTransactions::CreateJob with correct parameters" do
      expect(WalletTransactions::CreateJob).to have_been_enqueued.with(
        organization_id: organization.id,
        params: hash_including(
          name: nil,
          metadata: [{key: "valid_value", value: "also_valid"}]
        )
      )
    end

    context "when transaction metadata is a hash" do
      let(:create_params) do
        {
          external_customer_id: customer.external_id,
          rate_amount: "1",
          name: "Wallet1",
          currency: "EUR",
          paid_credits: "10",
          granted_credits: "10",
          expiration_at:,
          invoice_requires_successful_payment: true,
          transaction_metadata: {}
        }
      end

      it "returns a validation error" do
        expect(response).to have_http_status(:unprocessable_content)
        expect(json[:error_details][:metadata]).to include("invalid_type")
      end
    end
  end

  context "when transaction_name is provided" do
    let(:create_params) do
      {
        external_customer_id: customer.external_id,
        rate_amount: "1",
        name: "Wallet1",
        currency: "EUR",
        paid_credits: "10",
        granted_credits: "10",
        expiration_at:,
        transaction_name: "Custom Transaction Name"
      }
    end

    before do
      subject
    end

    it "schedules a WalletTransactions::CreateJob with the transaction name" do
      expect(WalletTransactions::CreateJob).to have_been_enqueued.with(
        organization_id: organization.id,
        params: hash_including(
          name: "Custom Transaction Name"
        )
      )
    end
  end

  context "when transaction_priority is provided" do
    let(:create_params) do
      {
        external_customer_id: customer.external_id,
        rate_amount: "1",
        name: "Wallet1",
        currency: "EUR",
        paid_credits: "10",
        granted_credits: "10",
        expiration_at:,
        transaction_priority: 5
      }
    end

    before { subject }

    it "schedules a WalletTransactions::CreateJob with the transaction priority" do
      expect(WalletTransactions::CreateJob).to have_been_enqueued.with(
        organization_id: organization.id,
        params: hash_including(
          priority: 5
        )
      )
    end
  end

  context "with recurring transaction rules", :premium do
    let(:create_params) do
      {
        external_customer_id: customer.external_id,
        rate_amount: "1",
        name: "Wallet1",
        currency: "EUR",
        paid_credits: "10",
        granted_credits: "10",
        expiration_at:,
        recurring_transaction_rules: [
          {
            trigger: "interval",
            interval: "monthly",
            ignore_paid_top_up_limits: true,
            invoice_custom_section: {invoice_custom_section_codes: [section_1.code]},
            payment_method: {
              payment_method_type: "provider",
              payment_method_id: payment_method.id
            }
          }
        ]
      }
    end

    it "returns a success" do
      subject

      recurring_rules = json[:wallet][:recurring_transaction_rules]

      expect(response).to have_http_status(:success)

      expect(recurring_rules).to be_present
      expect(recurring_rules.first[:interval]).to eq("monthly")
      expect(recurring_rules.first[:paid_credits]).to eq("10.0")
      expect(recurring_rules.first[:granted_credits]).to eq("10.0")
      expect(recurring_rules.first[:method]).to eq("fixed")
      expect(recurring_rules.first[:trigger]).to eq("interval")
      expect(recurring_rules.first[:ignore_paid_top_up_limits]).to eq(true)
      custom_section = recurring_rules.first[:applied_invoice_custom_sections].first
      expect(custom_section[:invoice_custom_section][:lago_id]).to eq(section_1.id)
      expect(recurring_rules.first[:payment_method][:payment_method_type]).to eq("provider")
      expect(recurring_rules.first[:payment_method][:payment_method_id]).to eq(payment_method.id)
    end

    context "when grants_target_top_up is true on a target rule" do
      let(:create_params) do
        {
          external_customer_id: customer.external_id,
          rate_amount: "1",
          name: "Wallet1",
          currency: "EUR",
          paid_credits: "10",
          granted_credits: "10",
          expiration_at:,
          recurring_transaction_rules: [
            {
              trigger: "interval",
              interval: "monthly",
              method: "target",
              target_ongoing_balance: "200",
              grants_target_top_up: true
            }
          ]
        }
      end

      it "creates the rule with grants_target_top_up true" do
        subject

        recurring_rules = json[:wallet][:recurring_transaction_rules]

        expect(response).to have_http_status(:success)
        expect(recurring_rules).to be_present
        expect(recurring_rules.first[:method]).to eq("target")
        expect(recurring_rules.first[:grants_target_top_up]).to eq(true)
      end
    end

    context "when grants_target_top_up is true on a fixed rule" do
      let(:create_params) do
        {
          external_customer_id: customer.external_id,
          rate_amount: "1",
          name: "Wallet1",
          currency: "EUR",
          paid_credits: "10",
          granted_credits: "10",
          expiration_at:,
          recurring_transaction_rules: [
            {
              trigger: "interval",
              interval: "monthly",
              method: "fixed",
              grants_target_top_up: true
            }
          ]
        }
      end

      it "returns a validation error" do
        subject

        expect(response).to have_http_status(:unprocessable_content)
        expect(json[:error_details][:recurring_transaction_rules]).to include("invalid_recurring_rule")
      end
    end

    context "when invoice_requires_successful_payment is set at the wallet level but the rule level" do
      let(:create_params) do
        {
          external_customer_id: customer.external_id,
          rate_amount: "1",
          name: "Wallet1",
          currency: "EUR",
          paid_credits: "10",
          expiration_at:,
          invoice_requires_successful_payment: true,
          recurring_transaction_rules: [
            {
              trigger: "interval",
              interval: "monthly"
            }
          ]
        }
      end

      it "follows the wallet configuration to create the rule" do
        subject

        recurring_rules = json[:wallet][:recurring_transaction_rules]

        expect(response).to have_http_status(:success)

        expect(json[:wallet][:invoice_requires_successful_payment]).to eq(true)
        expect(recurring_rules).to be_present
        expect(recurring_rules.first[:invoice_requires_successful_payment]).to eq(true)
      end
    end

    context "when invoice_requires_successful_payment is set at the rule level but not present at the wallet level" do
      let(:create_params) do
        {
          external_customer_id: customer.external_id,
          rate_amount: "1",
          name: "Wallet1",
          currency: "EUR",
          paid_credits: "10",
          expiration_at:,
          recurring_transaction_rules: [
            {
              trigger: "interval",
              interval: "monthly",
              invoice_requires_successful_payment: true
            }
          ]
        }
      end

      it "follows the wallet configuration to create the rule" do
        subject

        recurring_rules = json[:wallet][:recurring_transaction_rules]
        expect(response).to have_http_status(:success)
        expect(json[:wallet][:invoice_requires_successful_payment]).to eq(false)
        expect(recurring_rules).to be_present
        expect(recurring_rules.first[:invoice_requires_successful_payment]).to eq(true)
      end
    end

    context "with expiration_at transaction rule" do
      let(:create_params) do
        {
          external_customer_id: customer.external_id,
          rate_amount: "1",
          name: "Wallet1",
          currency: "EUR",
          recurring_transaction_rules: [
            {
              trigger: "interval",
              interval: "monthly",
              expiration_at:,
              invoice_requires_successful_payment: true
            }
          ]
        }
      end

      it "create the rule with correct expiration_at" do
        subject

        recurring_rules = json[:wallet][:recurring_transaction_rules]

        expect(response).to have_http_status(:success)
        expect(recurring_rules).to be_present
        expect(recurring_rules.first[:expiration_at]).to eq(expiration_at)
      end
    end

    context "with transaction metadata" do
      let(:create_params) do
        {
          external_customer_id: customer.external_id,
          rate_amount: "1",
          name: "Wallet1",
          currency: "EUR",
          paid_credits: "10",
          expiration_at:,
          recurring_transaction_rules: [
            {
              trigger: "interval",
              interval: "monthly",
              invoice_requires_successful_payment: true,
              transaction_metadata:
            }
          ]
        }
      end

      let(:transaction_metadata) { [{key: "valid_value", value: "also_valid"}] }

      it "create the rule with correct metadata" do
        subject

        recurring_rules = json[:wallet][:recurring_transaction_rules]

        expect(response).to have_http_status(:success)
        expect(recurring_rules).to be_present
        expect(recurring_rules.first[:transaction_metadata]).to eq(transaction_metadata)
      end

      context "when transaction metadata is a hash" do
        let(:transaction_metadata) { {key: "valid_value", value: "also_valid"} }

        it "returns a validation error" do
          subject
          expect(response).to have_http_status(:unprocessable_content)
          expect(json[:error_details][:recurring_transaction_rules]).to include("invalid_recurring_rule")
        end
      end
    end

    context "when transaction_name is set" do
      let(:create_params) do
        {
          external_customer_id: customer.external_id,
          rate_amount: "1",
          name: "Wallet1",
          currency: "EUR",
          paid_credits: "10",
          expiration_at:,
          recurring_transaction_rules: [
            {
              trigger: "interval",
              interval: "monthly",
              transaction_name: "Custom Wallet Top-up"
            }
          ]
        }
      end

      it "creates the rule with transaction_name" do
        subject

        recurring_rules = json[:wallet][:recurring_transaction_rules]

        expect(response).to have_http_status(:success)
        expect(recurring_rules).to be_present
        expect(recurring_rules.first[:transaction_name]).to eq("Custom Wallet Top-up")
      end
    end
  end

  context "with limitations" do
    let(:bm) { create(:billable_metric, organization:) }
    let(:create_params) do
      {
        external_customer_id: customer.external_id,
        rate_amount: "1",
        name: "Wallet1",
        currency: "EUR",
        paid_credits: "10",
        granted_credits: "10",
        expiration_at:,
        applies_to: {
          fee_types: %w[charge],
          billable_metric_codes: [bm.code]
        }
      }
    end

    it "returns a success" do
      subject

      limitations = json[:wallet][:applies_to]

      expect(response).to have_http_status(:success)
      expect(limitations).to be_present
      expect(limitations[:fee_types]).to eq(%w[charge])
      expect(limitations[:billable_metric_codes]).to eq([bm.code])
    end
  end

  context "with invoice_custom_section" do
    let(:invoice_custom_section) { nil }
    let(:create_params) do
      {
        external_customer_id: customer.external_id,
        rate_amount: "1",
        name: "Wallet1",
        currency: "EUR",
        invoice_custom_section:
      }
    end

    context "when skip_invoice_custom_sections is true" do
      let(:invoice_custom_section) {
        {skip_invoice_custom_sections: true}
      }

      it "set skip_invoice_custom_sections" do
        subject

        wallet = Wallet.find(json[:wallet][:lago_id])
        expect(wallet.skip_invoice_custom_sections).to be_truthy
      end
    end

    context "when skip_invoice_custom_sections is false" do
      let(:invoice_custom_section) {
        {
          skip_invoice_custom_sections: false,
          invoice_custom_section_codes: [section_1.code]
        }
      }

      it "creates with an attached section" do
        subject

        wallet = Wallet.find(json[:wallet][:lago_id])
        expect(wallet.skip_invoice_custom_sections).to be_falsey
        expect(wallet.applied_invoice_custom_sections.count).to be(1)
        expect(wallet.applied_invoice_custom_sections.pluck(:invoice_custom_section_id)).to include(section_1.id)
      end
    end
  end

  context "with wallet metadata" do
    let(:create_params) do
      {
        external_customer_id: customer.external_id,
        rate_amount: "1",
        name: "Wallet1",
        currency: "EUR",
        metadata: {"meta_key_1" => "meta_value_1", "meta_key_2" => "meta_value_2"}
      }
    end

    it "creates a wallet with metadata" do
      subject

      expect(response).to have_http_status(:success)
      expect(json[:wallet][:lago_id]).to be_present
      expect(json[:wallet][:metadata]).to eq(
        {
          meta_key_1: "meta_value_1",
          meta_key_2: "meta_value_2"
        }
      )
    end
  end

  context "when code is provided" do
    let(:create_params) do
      {
        external_customer_id: customer.external_id,
        rate_amount: "1",
        name: "Wallet1",
        code: "custom_wallet_code",
        currency: "EUR"
      }
    end

    it "creates a wallet with the provided code" do
      subject

      expect(response).to have_http_status(:success)
      expect(json[:wallet][:code]).to eq("custom_wallet_code")
    end
  end

  context "when code is not provided but name is" do
    let(:create_params) do
      {
        external_customer_id: customer.external_id,
        rate_amount: "1",
        name: "My Premium Wallet",
        currency: "EUR"
      }
    end

    it "creates a wallet with code derived from name" do
      subject

      expect(response).to have_http_status(:success)
      expect(json[:wallet][:code]).to eq("my_premium_wallet")
    end
  end

  context "when neither code nor name is provided" do
    let(:create_params) do
      {
        external_customer_id: customer.external_id,
        rate_amount: "1",
        currency: "EUR"
      }
    end

    it "creates a wallet with default code" do
      subject

      expect(response).to have_http_status(:success)
      expect(json[:wallet][:code]).to eq("default")
    end
  end

  context "when code is already taken for the customer" do
    before do
      create(:wallet, customer:, code: "existing_code")
    end

    let(:create_params) do
      {
        external_customer_id: customer.external_id,
        rate_amount: "1",
        name: "Wallet1",
        code: "existing_code",
        currency: "EUR"
      }
    end

    it "returns an error" do
      subject

      expect(response).to have_http_status(:unprocessable_content)
      expect(json[:error_details][:code]).to eq(["value_already_exist"])
    end
  end

  context "with applied_invoice_custom_sections in response" do
    it "includes applied_invoice_custom_sections in the serialized response" do
      subject

      expect(response).to have_http_status(:success)
      wallet = Wallet.find(json[:wallet][:lago_id])
      expect(json[:wallet][:applied_invoice_custom_sections].count).to eq(wallet.applied_invoice_custom_sections.count)
    end
  end

  context "when multi_entity_billing is enabled" do
    before { organization.update!(feature_flags: ["multi_entity_billing"]) }

    context "when billing_entity_code is provided" do
      let(:billing_entity) { create(:billing_entity, organization:, code: "be_wallet") }

      before { create_params[:billing_entity_code] = billing_entity.code }

      it "assigns the billing entity to the wallet" do
        subject

        expect(response).to have_http_status(:success)

        wallet = Wallet.find(json[:wallet][:lago_id])
        expect(wallet.billing_entity_id).to eq(billing_entity.id)
      end
    end

    context "when neither billing_entity_code nor billing_entity_id is provided" do
      it "creates the wallet without a billing entity" do
        subject

        expect(response).to have_http_status(:success)

        wallet = Wallet.find(json[:wallet][:lago_id])
        expect(wallet.billing_entity_id).to be_nil
      end
    end

    context "when billing_entity_code does not match any entity" do
      before { create_params[:billing_entity_code] = "nonexistent" }

      it "returns a not found error" do
        subject

        expect(response).to have_http_status(:not_found)
      end
    end
  end

  context "when multi_entity_billing is not enabled" do
    context "when billing_entity_code is provided" do
      let(:billing_entity) { create(:billing_entity, organization:, code: "be_wallet") }

      before { create_params[:billing_entity_code] = billing_entity.code }

      it "does not assign a billing entity" do
        subject

        expect(response).to have_http_status(:success)

        wallet = Wallet.find(json[:wallet][:lago_id])
        expect(wallet.billing_entity_id).to be_nil
      end
    end
  end
end

RSpec.shared_examples "a wallet create endpoint with billing_entity_id" do
  let(:create_params) do
    {
      external_customer_id: customer.external_id,
      rate_amount: "1",
      name: "Wallet1",
      currency: "EUR"
    }
  end

  context "when multi_entity_billing is enabled" do
    before { organization.update!(feature_flags: ["multi_entity_billing"]) }

    context "when billing_entity_id is provided" do
      let(:billing_entity) { create(:billing_entity, organization:) }

      before { create_params[:billing_entity_id] = billing_entity.id }

      it "assigns the billing entity to the wallet" do
        subject

        expect(response).to have_http_status(:success)

        wallet = Wallet.find(json[:wallet][:lago_id])
        expect(wallet.billing_entity_id).to eq(billing_entity.id)
      end
    end

    context "when billing_entity_id does not match any entity" do
      before { create_params[:billing_entity_id] = SecureRandom.uuid }

      it "returns a not found error" do
        subject

        expect(response).to have_http_status(:not_found)
      end
    end
  end

  context "when multi_entity_billing is not enabled" do
    context "when billing_entity_id is provided" do
      let(:billing_entity) { create(:billing_entity, organization:) }

      before { create_params[:billing_entity_id] = billing_entity.id }

      it "does not assign a billing entity" do
        subject

        expect(response).to have_http_status(:success)

        wallet = Wallet.find(json[:wallet][:lago_id])
        expect(wallet.billing_entity_id).to be_nil
      end
    end
  end
end

RSpec.shared_examples "a wallet update endpoint" do
  let(:wallet) { create(:wallet, customer:) }
  let(:expiration_at) { (Time.current + 1.year).iso8601 }
  let(:update_params) do
    {
      name: "wallet1",
      expiration_at:,
      priority: 5,
      invoice_requires_successful_payment: true,
      paid_top_up_min_amount_cents: 6_00,
      paid_top_up_max_amount_cents: 10_00,
      payment_method: {
        payment_method_type: "provider",
        payment_method_id: payment_method.id
      }
    }
  end

  before { wallet }

  include_examples "requires API permission", "wallet", "write"

  it "updates a wallet" do
    subject

    expect(response).to have_http_status(:success)

    expect(json[:wallet][:lago_id]).to eq(wallet.id)
    expect(json[:wallet][:name]).to eq(update_params[:name])
    expect(json[:wallet][:priority]).to eq(update_params[:priority])
    expect(json[:wallet][:expiration_at]).to eq(expiration_at)
    expect(json[:wallet][:invoice_requires_successful_payment]).to eq(true)
    expect(json[:wallet][:paid_top_up_min_amount_cents]).to eq(6_00)
    expect(json[:wallet][:paid_top_up_max_amount_cents]).to eq(10_00)
    expect(json[:wallet][:payment_method][:payment_method_type]).to eq("provider")
    expect(json[:wallet][:payment_method][:payment_method_id]).to eq(payment_method.id)

    expect(SendWebhookJob).to have_been_enqueued.with("wallet.updated", Wallet)
  end

  context "when wallet does not exist" do
    let(:id) { SecureRandom.uuid }

    it "returns not_found error" do
      subject
      expect(response).to have_http_status(:not_found)
      expect(SendWebhookJob).not_to have_been_enqueued.with("wallet.updated", Wallet)
    end
  end

  context "with limitations" do
    let(:bm) { create(:billable_metric, organization:) }
    let(:update_params) do
      {
        name: "wallet1",
        applies_to: {
          fee_types: %w[charge],
          billable_metric_codes: [bm.code]
        }
      }
    end

    it "updates a wallet" do
      subject

      expect(response).to have_http_status(:success)
      expect(json[:wallet][:lago_id]).to eq(wallet.id)
      expect(json[:wallet][:name]).to eq(update_params[:name])
      expect(json[:wallet][:applies_to][:fee_types]).to eq(%w[charge])
      expect(json[:wallet][:applies_to][:billable_metric_codes]).to eq([bm.code])

      expect(SendWebhookJob).to have_been_enqueued.with("wallet.updated", Wallet)
    end
  end

  context "with invoice_custom_section" do
    let(:invoice_custom_section) { nil }
    let(:update_params) do
      {
        name: "wallet1",
        invoice_custom_section:
      }
    end

    context "when skip_invoice_custom_sections is true" do
      let(:invoice_custom_section) {
        {skip_invoice_custom_sections: true}
      }

      it "set skip_invoice_custom_sections" do
        subject
        wallet.reload

        expect(wallet.skip_invoice_custom_sections).to be_truthy
      end
    end

    context "when skip_invoice_custom_sections is false" do
      let(:invoice_custom_section) {
        {
          skip_invoice_custom_sections: false,
          invoice_custom_section_codes: [section_1.code]
        }
      }

      it "creates with an attached section" do
        subject

        wallet.reload
        expect(wallet.skip_invoice_custom_sections).to be_falsey
        expect(wallet.applied_invoice_custom_sections.count).to be(1)
        expect(wallet.applied_invoice_custom_sections.pluck(:invoice_custom_section_id)).to include(section_1.id)
      end
    end
  end

  context "with recurring transaction rules", :premium do
    let(:recurring_transaction_rule) { create(:recurring_transaction_rule, wallet:) }
    let(:update_params) do
      {
        name: "wallet1",
        recurring_transaction_rules: [
          {
            lago_id: recurring_transaction_rule.id,
            method: "target",
            trigger: "interval",
            interval: "weekly",
            paid_credits: "105",
            granted_credits: "105",
            target_ongoing_balance: "300",
            invoice_requires_successful_payment: true,
            ignore_paid_top_up_limits: true,
            invoice_custom_section: {invoice_custom_section_codes: [section_1.code]},
            payment_method: {
              payment_method_type: "provider",
              payment_method_id: payment_method.id
            }
          }
        ]
      }
    end

    before { recurring_transaction_rule }

    it "returns a success" do
      subject

      recurring_rules = json[:wallet][:recurring_transaction_rules]

      expect(response).to have_http_status(:success)

      expect(json[:wallet][:invoice_requires_successful_payment]).to eq(false)
      expect(recurring_rules).to be_present
      expect(recurring_rules.first[:lago_id]).to eq(recurring_transaction_rule.id)
      expect(recurring_rules.first[:interval]).to eq("weekly")
      expect(recurring_rules.first[:paid_credits]).to eq("105.0")
      expect(recurring_rules.first[:granted_credits]).to eq("105.0")
      expect(recurring_rules.first[:method]).to eq("target")
      expect(recurring_rules.first[:trigger]).to eq("interval")
      expect(recurring_rules.first[:invoice_requires_successful_payment]).to eq(true)
      expect(recurring_rules.first[:ignore_paid_top_up_limits]).to eq(true)
      custom_section = recurring_rules.first[:applied_invoice_custom_sections].first
      expect(custom_section[:invoice_custom_section][:lago_id]).to eq(section_1.id)
      expect(recurring_rules.first[:payment_method][:payment_method_type]).to eq("provider")
      expect(recurring_rules.first[:payment_method][:payment_method_id]).to eq(payment_method.id)

      expect(SendWebhookJob).to have_been_enqueued.with("wallet.updated", Wallet)
    end

    context "when grants_target_top_up is updated to true on a target rule" do
      let(:update_params) do
        {
          name: "wallet1",
          recurring_transaction_rules: [
            {
              lago_id: recurring_transaction_rule.id,
              method: "target",
              trigger: "interval",
              interval: "weekly",
              target_ongoing_balance: "300",
              grants_target_top_up: true
            }
          ]
        }
      end

      it "updates the rule with grants_target_top_up true" do
        subject

        recurring_rules = json[:wallet][:recurring_transaction_rules]

        expect(response).to have_http_status(:success)
        expect(recurring_rules).to be_present
        expect(recurring_rules.first[:lago_id]).to eq(recurring_transaction_rule.id)
        expect(recurring_rules.first[:grants_target_top_up]).to eq(true)
      end
    end

    context "when transaction expiration_at is set" do
      let(:expiration_at) { (Time.current + 2.years).iso8601 }
      let(:update_params) do
        {
          name: "wallet1",
          invoice_requires_successful_payment: true,
          recurring_transaction_rules: [
            {
              method: "target",
              trigger: "interval",
              interval: "weekly",
              paid_credits: "105",
              granted_credits: "105",
              target_ongoing_balance: "300",
              expiration_at:
            }
          ]
        }
      end

      it "updates the rule" do
        subject

        recurring_rules = json[:wallet][:recurring_transaction_rules]
        expect(response).to have_http_status(:success)
        expect(recurring_rules).to be_present
        expect(recurring_rules.first[:expiration_at]).to eq(expiration_at)
        expect(SendWebhookJob).to have_been_enqueued.with("wallet.updated", Wallet)
      end
    end

    context "when transaction metadata is set" do
      let(:update_params) do
        {
          name: "wallet1",
          invoice_requires_successful_payment: true,
          recurring_transaction_rules: [
            {
              method: "target",
              trigger: "interval",
              interval: "weekly",
              paid_credits: "105",
              granted_credits: "105",
              target_ongoing_balance: "300",
              transaction_metadata: update_transaction_metadata
            }
          ]
        }
      end

      let(:update_transaction_metadata) { [{key: "update_key", value: "update_value"}] }

      it "updates the rule" do
        subject

        recurring_rules = json[:wallet][:recurring_transaction_rules]
        expect(response).to have_http_status(:success)
        expect(recurring_rules).to be_present
        expect(recurring_rules.first[:transaction_metadata]).to eq(update_transaction_metadata)

        expect(SendWebhookJob).to have_been_enqueued.with("wallet.updated", Wallet)
      end
    end

    context "when transaction_name is updated" do
      let(:update_params) do
        {
          name: "wallet1",
          recurring_transaction_rules: [
            {
              lago_id: recurring_transaction_rule.id,
              method: "target",
              trigger: "interval",
              interval: "weekly",
              paid_credits: "105",
              granted_credits: "105",
              target_ongoing_balance: "300",
              transaction_name: "Updated Transaction Name"
            }
          ]
        }
      end

      it "updates the rule with transaction_name" do
        subject

        recurring_rules = json[:wallet][:recurring_transaction_rules]
        expect(response).to have_http_status(:success)
        expect(recurring_rules).to be_present
        expect(recurring_rules.first[:transaction_name]).to eq("Updated Transaction Name")

        expect(SendWebhookJob).to have_been_enqueued.with("wallet.updated", Wallet)
      end
    end

    context "when invoice_requires_successful_payment is updated at the wallet level" do
      let(:update_params) do
        {
          name: "wallet1",
          invoice_requires_successful_payment: true,
          recurring_transaction_rules: [
            {
              lago_id: rule_id,
              method: "target",
              trigger: "interval",
              interval: "weekly",
              paid_credits: "105",
              granted_credits: "105",
              target_ongoing_balance: "300",
              expiration_at:
            }
          ]
        }
      end

      context "when the rule exists" do
        let(:rule_id) { recurring_transaction_rule.id }

        it "updates the wallet and the rule" do
          subject

          recurring_rules = json[:wallet][:recurring_transaction_rules]

          expect(response).to have_http_status(:success)

          expect(json[:wallet][:invoice_requires_successful_payment]).to eq(true)
          expect(recurring_rules).to be_present
          expect(recurring_rules.first[:lago_id]).to eq(recurring_transaction_rule.id)
          expect(recurring_rules.first[:invoice_requires_successful_payment]).to eq(false)
          expect(recurring_rules.first[:expiration_at]).to eq(expiration_at)

          expect(SendWebhookJob).to have_been_enqueued.with("wallet.updated", Wallet)
        end
      end

      context "when the rule does not exist" do
        let(:rule_id) { "does not exists in the db" }

        it "create a new rule and follow the new wallet configuration" do
          subject

          recurring_rules = json[:wallet][:recurring_transaction_rules]

          expect(response).to have_http_status(:success)

          expect(json[:wallet][:invoice_requires_successful_payment]).to eq(true)
          expect(recurring_rules).to be_present
          expect(recurring_rules.first[:invoice_requires_successful_payment]).to eq(true)

          expect(SendWebhookJob).to have_been_enqueued.with("wallet.updated", Wallet)
        end
      end

      context "when the rule does not exist but the param is passed explicitly" do
        let(:wallet) { create(:wallet, customer:, invoice_requires_successful_payment: true) }
        let(:update_params) do
          {
            name: "wallet1",
            invoice_requires_successful_payment: false,
            recurring_transaction_rules: [
              {
                lago_id: "does not exists in the db",
                method: "target",
                trigger: "interval",
                interval: "weekly",
                paid_credits: "105",
                granted_credits: "105",
                target_ongoing_balance: "300",
                invoice_requires_successful_payment: true
              }
            ]
          }
        end

        it "create a new rule and ignores wallet configuration" do
          expect(wallet.invoice_requires_successful_payment).to eq(true)

          subject

          recurring_rules = json[:wallet][:recurring_transaction_rules]

          expect(response).to have_http_status(:success)

          expect(json[:wallet][:invoice_requires_successful_payment]).to eq(false)
          expect(recurring_rules).to be_present
          expect(recurring_rules.first[:invoice_requires_successful_payment]).to eq(true)

          expect(SendWebhookJob).to have_been_enqueued.with("wallet.updated", Wallet)
        end
      end
    end
  end

  context "with wallet metadata" do
    let(:update_params) do
      {
        name: "wallet1",
        metadata: {"meta_key_1" => "updated_meta_value_1", "meta_key_3" => "meta_value_3"}
      }
    end

    it "updates a wallet with metadata" do
      subject

      expect(response).to have_http_status(:success)
      expect(json[:wallet][:lago_id]).to eq(wallet.id)
      expect(json[:wallet][:metadata]).to eq(
        {
          meta_key_1: "updated_meta_value_1",
          meta_key_3: "meta_value_3"
        }
      )
    end
  end

  context "when updating code" do
    let(:update_params) do
      {
        code: "updated_wallet_code"
      }
    end

    it "updates the wallet code" do
      subject

      expect(response).to have_http_status(:success)
      expect(json[:wallet][:lago_id]).to eq(wallet.id)
      expect(json[:wallet][:code]).to eq("updated_wallet_code")
    end
  end

  context "when updating code to a value already taken for the customer" do
    before do
      create(:wallet, customer:, code: "taken_code")
    end

    let(:update_params) do
      {
        code: "taken_code"
      }
    end

    it "returns an error" do
      subject

      expect(response).to have_http_status(:unprocessable_content)
      expect(json[:error_details][:code]).to eq(["value_already_exist"])
    end
  end

  context "with applied_invoice_custom_sections in response" do
    before { create(:wallet_applied_invoice_custom_section, wallet:) }

    it "includes applied_invoice_custom_sections in the serialized response" do
      subject

      expect(response).to have_http_status(:success)
      expect(json[:wallet][:applied_invoice_custom_sections].count).to eq(1)
    end
  end

  context "with billing_entity_code" do
    let(:initial_billing_entity) { create(:billing_entity, organization:, code: "initial_be") }
    let(:target_billing_entity) { create(:billing_entity, organization:, code: "target_be") }
    let(:wallet) { create(:wallet, customer:, billing_entity: initial_billing_entity) }

    context "when multi_entity_billing is enabled" do
      before { organization.update!(feature_flags: ["multi_entity_billing"]) }

      context "when billing_entity_code matches an entity" do
        let(:update_params) { {billing_entity_code: target_billing_entity.code} }

        it "moves the wallet to the new billing entity" do
          subject

          expect(response).to have_http_status(:success)
          expect(wallet.reload.billing_entity_id).to eq(target_billing_entity.id)
          expect(json[:wallet][:billing_entity_code]).to eq(target_billing_entity.code)
        end
      end

      context "when billing_entity_code does not match any entity" do
        let(:update_params) { {billing_entity_code: "nonexistent"} }

        it "returns a not found error and leaves the wallet untouched" do
          subject

          expect(response).to be_not_found_error("billing_entity")
          expect(wallet.reload.billing_entity_id).to eq(initial_billing_entity.id)
        end
      end
    end

    context "when multi_entity_billing is not enabled" do
      let(:update_params) { {billing_entity_code: target_billing_entity.code} }

      it "ignores billing_entity_code and leaves the wallet untouched" do
        subject

        expect(response).to have_http_status(:success)
        expect(wallet.reload.billing_entity_id).to eq(initial_billing_entity.id)
      end
    end
  end
end

RSpec.shared_examples "a wallet show endpoint" do
  let(:wallet) { create(:wallet, customer:) }

  include_examples "requires API permission", "wallet", "read"

  it "returns a wallet" do
    subject

    expect(response).to have_http_status(:success)
    expect(json[:wallet][:lago_id]).to eq(wallet.id)
    expect(json[:wallet][:name]).to eq(wallet.name)
    expect(json[:wallet][:priority]).to eq(50)
  end

  context "when wallet does not exist" do
    let(:id) { SecureRandom.uuid }

    it "returns not found" do
      subject
      expect(response).to have_http_status(:not_found)
    end
  end

  context "with applied_invoice_custom_sections in response" do
    before { create(:wallet_applied_invoice_custom_section, wallet:) }

    it "includes applied_invoice_custom_sections in the serialized response" do
      subject

      expect(response).to have_http_status(:success)
      expect(json[:wallet][:applied_invoice_custom_sections].count).to eq(1)
    end
  end
end

RSpec.shared_examples "a wallet terminate endpoint" do
  let(:wallet) { create(:wallet, customer:) }

  include_examples "requires API permission", "wallet", "write"

  it "terminates a wallet" do
    subject
    expect(wallet.reload.status).to eq("terminated")
  end

  it "returns terminated wallet" do
    subject

    expect(response).to have_http_status(:success)
    expect(json[:wallet][:lago_id]).to eq(wallet.id)
    expect(json[:wallet][:name]).to eq(wallet.name)
  end

  it "sends a wallet.terminated webhook" do
    expect { subject }.to have_enqueued_job(SendWebhookJob).with("wallet.terminated", Wallet)
  end

  context "when wallet does not exist" do
    let(:id) { SecureRandom.uuid }

    it "returns not_found error" do
      subject
      expect(response).to have_http_status(:not_found)
    end
  end

  context "when wallet id does not belong to the current organization" do
    let(:other_org_wallet) { create(:wallet) }
    let(:id) { other_org_wallet.id }

    it "returns a not found error" do
      subject
      expect(response).to have_http_status(:not_found)
    end
  end

  context "with applied_invoice_custom_sections in response" do
    before { create(:wallet_applied_invoice_custom_section, wallet:) }

    it "includes applied_invoice_custom_sections in the serialized response" do
      subject

      expect(response).to have_http_status(:success)
      expect(json[:wallet][:applied_invoice_custom_sections].count).to eq(1)
    end
  end
end

RSpec.shared_examples "a wallet index endpoint" do
  let!(:wallet) { create(:wallet, customer:) }
  let(:external_id) { customer.external_id }
  let(:params) { {page: 1, per_page: 1} }

  include_examples "requires API permission", "wallet", "read"

  it "returns wallets" do
    subject

    expect(response).to have_http_status(:success)
    expect(json[:wallets].count).to eq(1)
    expect(json[:wallets].first[:lago_id]).to eq(wallet.id)
    expect(json[:wallets].first[:name]).to eq(wallet.name)
    expect(json[:wallets].first[:recurring_transaction_rules]).to be_empty
    expect(json[:wallets].first[:applies_to]).to be_present
  end

  context "with pagination" do
    before { create(:wallet, customer:) }

    it "returns wallets with correct meta data" do
      subject

      expect(response).to have_http_status(:success)

      expect(json[:wallets].count).to eq(1)
      expect(json[:meta][:current_page]).to eq(1)
      expect(json[:meta][:next_page]).to eq(2)
      expect(json[:meta][:prev_page]).to eq(nil)
      expect(json[:meta][:total_pages]).to eq(2)
      expect(json[:meta][:total_count]).to eq(2)
    end
  end

  context "with applied_invoice_custom_sections in response" do
    let(:params) { {} }

    before { create(:wallet_applied_invoice_custom_section, wallet:) }

    it "includes applied_invoice_custom_sections in the serialized response" do
      subject

      expect(response).to have_http_status(:success)
      expect(json[:wallets].first[:applied_invoice_custom_sections].count).to eq(1)
    end
  end

  context "with currency filter" do
    let!(:brl_wallet) { create(:wallet, customer:, currency: "BRL") }
    let(:params) { {currency: "BRL"} }

    it "returns only wallets with matching currency" do
      subject

      expect(response).to have_http_status(:success)
      expect(json[:wallets].count).to eq(1)
      expect(json[:wallets].first[:lago_id]).to eq(brl_wallet.id)
    end
  end

  context "with N+1 query detection", bullet: {n_plus_one_query: true, unused_eager_loading: false} do
    let(:params) { {} }

    before do
      [wallet, create(:wallet, customer:), create(:wallet, customer:)].each do |w|
        create(:wallet_target, wallet: w)
        create(:wallet_applied_invoice_custom_section, wallet: w)
        create(:recurring_transaction_rule, wallet: w)
      end
    end

    it "does not trigger N+1 queries on wallet associations" do
      subject

      expect(response).to have_http_status(:success)
      expect(json[:wallets].count).to eq(3)
      json[:wallets].each do |wallet_payload|
        expect(wallet_payload[:applies_to][:billable_metric_codes]).to be_present
        expect(wallet_payload[:recurring_transaction_rules]).to be_present
        expect(wallet_payload[:applied_invoice_custom_sections]).to be_present
      end
    end
  end
end
