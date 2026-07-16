# frozen_string_literal: true

require "rails_helper"

describe "Add customer-specific taxes" do
  let(:organization) { create(:organization, country: "FR", eu_tax_management: false, billing_entities: [create(:billing_entity, country: "FR")]) }
  let(:plan) { create(:plan, organization:, pay_in_advance: true, amount_cents: 149_00) }

  let(:american_attributes) do
    {
      name: "John",
      country: "US",
      address_line1: "123 Main St",
      address_line2: "",
      state: "Colorado",
      city: "Denver",
      zipcode: "80095",
      currency: "USD"
    }
  end

  let(:french_attributes) do
    {
      name: "Jean",
      country: "FR",
      address_line1: "123 Avenue du General",
      address_line2: "",
      state: "",
      city: "Paris",
      zipcode: "75018",
      currency: "EUR"
    }
  end

  let(:italian_attributes) do
    {
      country: "IT",
      address_line1: "123 Via Marconi",
      address_line2: "",
      state: "",
      city: "Roma",
      zipcode: "00146",
      currency: "EUR"
    }
  end

  def enable_eu_tax_management!
    Organizations::UpdateService.call!(organization:, params: {eu_tax_management: true})
  end

  include_context "with webhook tracking"

  context "when customer are created after the feature was enabled" do
    it "create taxes" do
      enable_eu_tax_management!

      create_or_update_customer(american_attributes.merge(external_id: "user_usa_123"))
      expect(Customer.find_by(external_id: "user_usa_123").taxes.sole.code).to eq "lago_eu_tax_exempt"

      create_or_update_customer(french_attributes.merge(external_id: "user_fr_123"))
      expect(Customer.find_by(external_id: "user_fr_123").taxes.sole.code).to eq "lago_eu_fr_standard"

      create_or_update_customer(italian_attributes.merge(external_id: "user_it_123"))
      expect(Customer.find_by(external_id: "user_it_123").taxes.sole.code).to eq "lago_eu_it_standard"

      webhooks_sent.clear
      # Update customer to provide an INVALID EU VAT identifier
      # Nothing changes and no API call is made
      create_or_update_customer({external_id: "user_it_123", tax_identification_number: "IT123"})
      expect(Customer.find_by(external_id: "user_it_123").taxes.reload.sole.code).to eq "lago_eu_it_standard"
      expect(webhooks_sent.find { it["webhook_type"] == "customer.vies_check" }.dig("customer", "vies_check")).to eq({
        "valid" => false,
        "valid_format" => false
      })

      webhooks_sent.clear
      # Update customer to provide a valid EU VAT identifier
      # A call is made to VIES api, we mock the service rather than the HTTP call because it's a SOAP API
      # This customer now have 0% vat
      mock_vies_check!("IT12345678901")
      create_or_update_customer({external_id: "user_it_123", tax_identification_number: "IT12345678901"})
      expect(Customer.find_by(external_id: "user_it_123").taxes.reload.sole.code).to eq "lago_eu_reverse_charge"
      expect(webhooks_sent.find { it["webhook_type"] == "customer.vies_check" }.dig("customer", "vies_check")).to eq({
        "country_code" => "IT",
        "vat_number" => "IT12345678901"
      })

      mock_vies_check!("FR12345678901")
      create_or_update_customer({external_id: "user_fr_123", tax_identification_number: "FR12345678901"})
      expect(Customer.find_by(external_id: "user_fr_123").taxes.sole.code).to eq "lago_eu_fr_standard"

      customer = Customer.find_by(external_id: "user_it_123")
      # If I had a custom tax for this Customer
      # It removes the automatic VAT
      create_tax({name: "Banking rates", code: "banking_rates", rate: 1.3})
      create_or_update_customer({external_id: customer.external_id, tax_codes: ["banking_rates"]})
      expect(customer.taxes.sole.code).to eq "banking_rates"

      # Make an invoice with this tax
      addon = create(:add_on, code: :test, organization:)
      create_one_off_invoice(customer, [addon], taxes: ["banking_rates"])
      expect(customer.invoices.sole.taxes.sole.code).to eq "banking_rates"

      # Then, remove the tax_identification_number for the customer
      # The custom tax is overridden by the default VAT of the country, even if an invoice used the previous taxes
      create_or_update_customer({external_id: customer.external_id, tax_identification_number: nil})
      expect(customer.taxes.sole.code).to eq "lago_eu_it_standard"
    end
  end

  context "when VIES returns an error" do
    let(:retry_job) { class_double(Customers::ViesCheckJob) }

    it "does not change taxes but send the webhook" do
      enable_eu_tax_management!

      create_or_update_customer(french_attributes.merge(external_id: "user_fr_123"))
      expect(Customer.find_by(external_id: "user_fr_123").taxes.sole.code).to eq "lago_eu_fr_standard"

      webhooks_sent.clear
      vat_number = "FR12345678901"
      allow_any_instance_of(Valvat).to receive(:exists?) # rubocop:disable RSpec/AnyInstance
        .and_raise(::Valvat::RateLimitError.new("rate limit exceeded", Valvat::Lookup::VIES))

      allow(Customers::ViesCheckJob).to receive(:set).and_return retry_job
      allow(retry_job).to receive(:perform_later)

      create_or_update_customer({external_id: "user_fr_123", tax_identification_number: vat_number})

      expect(Customer.find_by(external_id: "user_fr_123").taxes.reload.sole.code).to eq "lago_eu_fr_standard"
      expect(webhooks_sent.find { it["webhook_type"] == "customer.vies_check" }.dig("customer", "vies_check")).to eq({
        "valid" => false,
        "valid_format" => true,
        "error" => "The VIES web service returned the error: rate limit exceeded"
      })
    end
  end

  context "when VIES fails and invoice is blocked until retry succeeds" do
    let(:vat_number) { "IT12345678901" }
    let(:retry_job) { class_double(Customers::ViesCheckJob) }

    def setup_customer_with_pending_vies_check!
      enable_eu_tax_management!

      create_or_update_customer(italian_attributes.merge(external_id: "user_it_123"))
      customer = Customer.find_by(external_id: "user_it_123")
      expect(customer.taxes.sole.code).to eq "lago_eu_it_standard"

      # Update with VAT number - VIES fails
      allow_any_instance_of(Valvat).to receive(:exists?) # rubocop:disable RSpec/AnyInstance
        .and_raise(::Valvat::RateLimitError.new("rate limit exceeded", Valvat::Lookup::VIES))
      allow(Customers::ViesCheckJob).to receive(:set).and_return(retry_job)
      allow(retry_job).to receive(:perform_later)

      create_or_update_customer({external_id: "user_it_123", tax_identification_number: vat_number})

      expect(customer.reload.pending_vies_check).to be_present
      expect(customer.vies_check_in_progress?).to be true

      customer
    end

    def resolve_vies_check!(customer)
      mock_vies_check!(vat_number)
      Customers::ViesCheckJob.perform_now(customer)

      expect(customer.reload.pending_vies_check).to be_nil
      expect(customer.vies_check_in_progress?).to be false

      perform_enqueued_jobs
    end

    def expect_pending_invoice(invoice)
      expect(invoice.status).to eq "pending"
      expect(invoice.tax_status).to eq "pending"

      # Fees should exist but have no taxes applied yet
      invoice.fees.each do |fee|
        expect(fee.applied_taxes).to be_empty
        expect(fee.taxes_amount_cents).to eq 0
      end
    end

    def expect_finalized_invoice_with_reverse_charge(invoice)
      invoice.reload
      expect(invoice.status).to eq "finalized"
      expect(invoice.tax_status).to eq "succeeded"

      # Reverse charge: 0% tax
      expect(invoice.taxes_amount_cents).to eq 0
      expect(invoice.applied_taxes.sole.tax_code).to eq "lago_eu_reverse_charge"

      invoice.fees.each do |fee|
        next if fee.amount_cents.zero?

        expect(fee.applied_taxes.sole.tax_code).to eq "lago_eu_reverse_charge"
        expect(fee.taxes_amount_cents).to eq 0
      end
    end

    context "with subscription pay-in-advance plan invoice" do
      it "blocks finalization and applies reverse charge after VIES succeeds" do
        customer = setup_customer_with_pending_vies_check!

        create_subscription({
          external_customer_id: customer.external_id,
          external_id: "sub_#{customer.external_id}",
          plan_code: plan.code
        })

        invoice = customer.invoices.sole
        expect_pending_invoice(invoice)

        resolve_vies_check!(customer)
        expect_finalized_invoice_with_reverse_charge(invoice)
      end
    end

    context "with pay-in-advance charge invoice" do
      let(:billable_metric) { create(:billable_metric, organization:, field_name: "item_id") }
      let(:pay_in_arrear_plan) { create(:plan, organization:, pay_in_advance: false, amount_cents: 0) }

      it "blocks finalization and applies reverse charge after VIES succeeds" do
        customer = setup_customer_with_pending_vies_check!

        create(:standard_charge, :pay_in_advance, billable_metric:, plan: pay_in_arrear_plan,
          invoiceable: true, properties: {amount: "100"})

        create_subscription({
          external_customer_id: customer.external_id,
          external_id: "sub_#{customer.external_id}",
          plan_code: pay_in_arrear_plan.code
        })

        # Send event that triggers pay-in-advance charge invoice
        create_event({
          code: billable_metric.code,
          transaction_id: SecureRandom.uuid,
          external_subscription_id: "sub_#{customer.external_id}",
          properties: {item_id: "item_1"}
        })

        charge_invoice = customer.invoices.order(created_at: :desc).first
        expect(charge_invoice.fees.charge.count).to eq 1
        expect_pending_invoice(charge_invoice)

        resolve_vies_check!(customer)
        expect_finalized_invoice_with_reverse_charge(charge_invoice)
      end
    end

    context "with one-off invoice" do
      it "blocks finalization and applies reverse charge after VIES succeeds" do
        customer = setup_customer_with_pending_vies_check!

        addon = create(:add_on, code: :test_addon, organization:, amount_cents: 5000)
        create_one_off_invoice(customer, [addon])

        invoice = customer.invoices.sole
        expect_pending_invoice(invoice)

        webhooks_sent.clear
        resolve_vies_check!(customer)
        # Process webhook jobs enqueued via after_commit
        perform_all_enqueued_jobs
        expect_finalized_invoice_with_reverse_charge(invoice)

        # One-off invoices must use the one_off_created webhook type
        expect(webhooks_sent.find { it["webhook_type"] == "invoice.one_off_created" }).to be_present
        expect(webhooks_sent.find { it["webhook_type"] == "invoice.created" }).to be_nil
      end
    end

    context "with subscription periodic billing invoice" do
      let(:pay_in_arrear_plan) { create(:plan, organization:, pay_in_advance: false, amount_cents: 1000) }

      it "blocks finalization and applies reverse charge after VIES succeeds" do
        customer = setup_customer_with_pending_vies_check!

        travel_to(DateTime.new(2024, 1, 1, 0, 0)) do
          create_subscription({
            external_customer_id: customer.external_id,
            external_id: "sub_#{customer.external_id}",
            plan_code: pay_in_arrear_plan.code
          })
        end

        # Trigger periodic billing
        travel_to(DateTime.new(2024, 2, 1, 0, 0)) do
          perform_billing
        end

        invoice = customer.invoices.order(created_at: :desc).first
        expect(invoice.invoice_type).to eq "subscription"
        expect_pending_invoice(invoice)

        resolve_vies_check!(customer)
        expect_finalized_invoice_with_reverse_charge(invoice)
      end
    end
  end

  context "when customer are created before the feature was enabled" do
    it "does not create taxes until the customer is updated" do
      create_or_update_customer(american_attributes.merge(external_id: "user_usa_123"))
      expect(Customer.find_by(external_id: "user_usa_123").taxes).to be_empty

      enable_eu_tax_management!
      expect(Customer.find_by(external_id: "user_usa_123").taxes).to be_empty

      create_or_update_customer({external_id: "user_usa_123", tax_identification_number: "US-111"}) # Not EU VAT
      expect(Customer.find_by(external_id: "user_usa_123").taxes.sole.code).to eq "lago_eu_tax_exempt"
    end
  end

  context "when customer changes country" do
    it "updates taxes" do
      enable_eu_tax_management!

      create_or_update_customer(french_attributes.merge({external_id: "user_moving"}))
      customer = Customer.find_by(external_id: "user_moving")
      expect(customer.reload.taxes.sole.code).to eq "lago_eu_fr_standard"

      create_or_update_customer({external_id: customer.external_id, country: "DE"})
      expect(customer.reload.taxes.sole.code).to eq "lago_eu_de_standard"
    end
  end

  context "when customer have an invoice with other taxes" do
    it "does not affect the customer taxes" do
      enable_eu_tax_management!

      create_or_update_customer(italian_attributes.merge(external_id: "user_it_123"))
      customer = Customer.find_by(external_id: "user_it_123")
      expect(customer.taxes.sole.code).to eq "lago_eu_it_standard"

      # Make an invoice with another tax
      create_tax({name: "Banking rates", code: "banking_rates", rate: 1.3})
      addon = create(:add_on, code: :test, organization:)
      create_one_off_invoice(customer, [addon], taxes: ["banking_rates"])
      expect(customer.invoices.sole.taxes.sole.code).to eq "banking_rates"

      # The customer tax is unaffected
      expect(customer.taxes.sole.code).to eq "lago_eu_it_standard"
    end
  end

  context "when organization has a default tax" do
    it "does not affect the customer taxes" do
      enable_eu_tax_management!
      organization.taxes.where(code: "lago_eu_fr_standard").update!(applied_to_organization: true)

      mock_vies_check!("IT12345678901")
      create_or_update_customer(italian_attributes.merge(
        external_id: "user_it_123", tax_identification_number: "IT12345678901"
      ))
      customer = Customer.find_by(external_id: "user_it_123")
      expect(customer.taxes.reload.sole.code).to eq "lago_eu_reverse_charge"

      create_subscription({
        external_customer_id: customer.external_id,
        external_id: "sub_#{customer.external_id}",
        plan_code: plan.code
      })

      # The default organization tax is not applied
      expect(customer.invoices.sole.taxes.sole.code).to eq "lago_eu_reverse_charge"
    end
  end

  context "when charge has a dedicated tax" do
    it "does not affect the customer taxes" do
      enable_eu_tax_management!
      billable_metric = create(:billable_metric, organization:, field_name: "item_id")
      charge = create(:standard_charge, :pay_in_advance, billable_metric:, plan:)
      create(:charge_applied_tax, charge:, tax: Tax.find_by(code: "lago_eu_fr_standard"))

      mock_vies_check!("IT12345678901")
      create_or_update_customer(italian_attributes.merge(
        external_id: "user_it_123", tax_identification_number: "IT12345678901"
      ))
      customer = Customer.find_by(external_id: "user_it_123")
      expect(customer.taxes.reload.sole.code).to eq "lago_eu_reverse_charge"

      create_subscription({
        external_customer_id: customer.external_id,
        external_id: "sub_#{customer.external_id}",
        plan_code: plan.code
      })
      expect(customer.invoices.sole.taxes.sole.code).to eq "lago_eu_reverse_charge"

      create_event({
        code: billable_metric.code,
        transaction_id: SecureRandom.uuid,
        external_subscription_id: "sub_#{customer.external_id}"
      })

      # The Advance fee charge has the charge taxes even if the customer has a different tax
      advance_fee_invoice = customer.invoices.order(created_at: :desc).first
      expect(advance_fee_invoice.taxes.sole.code).to eq "lago_eu_fr_standard"
      expect(advance_fee_invoice.fees.charge.sole.taxes.sole.code).to eq "lago_eu_fr_standard"
      expect(customer.taxes.reload.sole.code).to eq "lago_eu_reverse_charge"
    end
  end
end
