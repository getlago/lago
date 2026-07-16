# frozen_string_literal: true

require "rails_helper"

RSpec.describe Resolvers::InvoiceResolver do
  let(:required_permission) { "invoices:view" }
  let(:query) do
    <<~GQL
      query($id: ID!) {
        invoice(id: $id) {
          id
          number
          feesAmountCents
          couponsAmountCents
          creditNotesAmountCents
          prepaidCreditAmountCents
          refundableAmountCents
          creditableAmountCents
          paymentDisputeLosable
          paymentStatus
          status
          customer {
            id
            name
            deletedAt
          }
          appliedTaxes {
            taxCode
            taxName
            taxRate
            taxDescription
            amountCents
            amountCurrency
          }
          invoiceSubscriptions {
            fromDatetime
            toDatetime
            chargesFromDatetime
            chargesToDatetime
            subscription {
              id
            }
            fees {
              currency
              id
              itemType
              itemCode
              itemName
              charge { id billableMetric { code } }
              taxesRate
              taxesAmountCents
              trueUpFee { id }
              trueUpParentFee { id }
              units
              preciseUnitAmount
              chargeFilter { invoiceDisplayName values }
              presentationBreakdowns { presentationBy units }
              appliedTaxes {
                taxCode
                taxName
                taxRate
                taxDescription
                amountCents
                amountCurrency
              }
              properties {
                fromDatetime
                toDatetime
              }
            }
          }
          subscriptions {
            id
          }
          fees {
            id
            itemType
            itemCode
            itemName
            creditableAmountCents
            presentationBreakdowns { presentationBy units }
            charge {
              id
              billableMetric {
                code
                filters { key values }
              }
              filters { invoiceDisplayName values }
            }
            pricingUnitUsage {
              id
              amountCents
              conversionRate
              preciseAmountCents
              shortName
              unitAmountCents
              pricingUnit {
                id
                code
                name
                shortName
              }
            }
            walletTransaction {
              name
              walletName
            }
          }
        }
      }
    GQL
  end

  let(:membership) { create(:membership) }
  let(:organization) { membership.organization }
  let(:customer) { create(:customer, organization:) }
  let(:invoice_subscription) { create(:invoice_subscription, invoice:) }
  let(:invoice) { create(:invoice, customer:, organization:, fees_amount_cents: 10) }
  let(:subscription) { invoice_subscription.subscription }
  let(:fee) do
    create(:fee, subscription:, invoice:, amount_cents: 10, properties: {
      from_datetime: Time.current.beginning_of_month,
      to_datetime: Time.current.end_of_month,
      charges_from_datetime: Time.current.beginning_of_month - 1.month,
      charges_to_datetime: Time.current.end_of_month - 1.month,
      fixed_charges_from_datetime: Time.current.beginning_of_month + 1.month,
      fixed_charges_to_datetime: Time.current.end_of_month + 1.month
    }, presentation_breakdowns: [build(:presentation_breakdown, organization:)])
  end
  let(:charge_with_display_keys) do
    create(:standard_charge, properties: {
      "amount" => "100",
      "presentation_group_keys" => [{"value" => "department", "options" => {"display_in_invoice" => true}}]
    })
  end
  let(:charge_fee) do
    create(:charge_fee, charge: charge_with_display_keys, subscription:, invoice:, amount_cents: 10, properties: {
      from_datetime: Time.current.beginning_of_month,
      to_datetime: Time.current.end_of_month,
      charges_from_datetime: Time.current.beginning_of_month - 1.month,
      charges_to_datetime: Time.current.end_of_month - 1.month,
      fixed_charges_from_datetime: Time.current.beginning_of_month + 1.month,
      fixed_charges_to_datetime: Time.current.end_of_month + 1.month
    }, presentation_breakdowns: [build(:presentation_breakdown, organization:)])
  end
  let(:fixed_charge_fee) do
    create(:fixed_charge_fee, subscription:, invoice:, amount_cents: 10, properties: {
      from_datetime: Time.current.beginning_of_month,
      to_datetime: Time.current.end_of_month,
      charges_from_datetime: Time.current.beginning_of_month - 1.month,
      charges_to_datetime: Time.current.end_of_month - 1.month,
      fixed_charges_from_datetime: Time.current.beginning_of_month + 1.month,
      fixed_charges_to_datetime: Time.current.end_of_month + 1.month
    }, presentation_breakdowns: [build(:presentation_breakdown, organization:)])
  end

  before do
    fee
    charge_fee
    fixed_charge_fee
    invoice
  end

  it_behaves_like "requires current user"
  it_behaves_like "requires current organization"
  it_behaves_like "requires permission", "invoices:view"

  it "returns a single invoice" do
    result = execute_graphql(
      current_user: membership.user,
      current_organization: organization,
      permissions: required_permission,
      query:,
      variables: {
        id: invoice.id
      }
    )

    data = result["data"]["invoice"]

    expect(data["id"]).to eq(invoice.id)
    expect(data["number"]).to eq(invoice.number)
    expect(data["paymentStatus"]).to eq(invoice.payment_status)
    expect(data["paymentDisputeLosable"]).to eq(true)
    expect(data["status"]).to eq(invoice.status)
    expect(data["customer"]["id"]).to eq(customer.id)
    expect(data["customer"]["name"]).to eq(customer.name)
    expect(data["invoiceSubscriptions"][0]["subscription"]["id"]).to eq(subscription.id)

    subscription_fee = data["invoiceSubscriptions"][0]["fees"].find { |f| f["itemType"] == "subscription" }
    expect(subscription_fee["id"]).to eq(fee.id)
    expect(subscription_fee["properties"]["fromDatetime"]).to eq(Time.current.beginning_of_month.to_datetime.iso8601)
    expect(subscription_fee["properties"]["toDatetime"]).to eq(Time.current.end_of_month.to_datetime.iso8601)
    expect(subscription_fee["presentationBreakdowns"]).to eq([])

    charge_fee_result = data["invoiceSubscriptions"][0]["fees"].find { |f| f["itemType"] == "charge" }
    expect(charge_fee_result["id"]).to eq(charge_fee.id)
    expect(charge_fee_result["properties"]["fromDatetime"]).to eq((Time.current.beginning_of_month - 1.month).to_datetime.iso8601)
    expect(charge_fee_result["properties"]["toDatetime"]).to eq((Time.current.end_of_month - 1.month).to_datetime.iso8601)
    expect(charge_fee_result["presentationBreakdowns"]).to eq([
      {"presentationBy" => {"department" => "engineering"}, "units" => "60.0"}
    ])

    fixed_charge_fee_result = data["invoiceSubscriptions"][0]["fees"].find { |f| f["itemType"] == "fixed_charge" }
    expect(fixed_charge_fee_result["id"]).to eq(fixed_charge_fee.id)
    expect(fixed_charge_fee_result["properties"]["fromDatetime"]).to eq((Time.current.beginning_of_month + 1.month).to_datetime.iso8601)
    expect(fixed_charge_fee_result["properties"]["toDatetime"]).to eq((Time.current.end_of_month + 1.month).to_datetime.iso8601)
    expect(fixed_charge_fee_result["presentationBreakdowns"]).to eq([])
  end

  it "includes filters for the fee" do
    billable_metric_filter = create(:billable_metric_filter, key: "cloud", values: %w[aws gcp])
    charge_filter = create(:charge_filter, invoice_display_name: nil)
    charge_filter_value = create(:charge_filter_value, billable_metric_filter:, charge_filter:, values: ["aws"])

    fee.update!(charge_filter_id: charge_filter.id)

    result = execute_graphql(
      current_user: membership.user,
      current_organization: organization,
      permissions: required_permission,
      query:,
      variables: {id: invoice.id}
    )

    fee_result = result["data"]["invoice"]["invoiceSubscriptions"][0]["fees"].find { |f| f["id"] == fee.id }
    expect(fee_result["chargeFilter"]["values"][billable_metric_filter.key]).to eq(charge_filter_value.values)
  end

  it "includes pricing unit usage when available" do
    pricing_unit = create(:pricing_unit, organization:)
    billable_metric = create(:billable_metric, organization:)
    charge = create(:standard_charge, billable_metric:, properties: {
      "amount" => "100",
      "presentation_group_keys" => [{"value" => "department", "options" => {"display_in_invoice" => true}}]
    })
    applied_pricing_unit = create(:applied_pricing_unit, pricing_unit:, conversion_rate: 2.5)

    pricing_unit_usage = build(
      :pricing_unit_usage,
      pricing_unit:,
      organization:,
      short_name: pricing_unit.short_name,
      conversion_rate: applied_pricing_unit.conversion_rate,
      amount_cents: 40,
      precise_amount_cents: 40.0,
      unit_amount_cents: 20
    )

    fee_with_usage = create(
      :fee,
      subscription:,
      invoice:,
      charge:,
      amount_cents: 100,
      organization:,
      pricing_unit_usage:,
      presentation_breakdowns: [build(:presentation_breakdown, organization:)]
    )

    result = execute_graphql(
      current_user: membership.user,
      current_organization: organization,
      permissions: required_permission,
      query:,
      variables: {id: invoice.id}
    )

    fees = result["data"]["invoice"]["fees"]
    fee_data = fees.find { |f| f["id"] == fee_with_usage.id }

    expect(fee_data["pricingUnitUsage"]).to be_present
    expect(fee_data["pricingUnitUsage"]["amountCents"]).to eq(pricing_unit_usage.amount_cents.to_s)
    expect(fee_data["pricingUnitUsage"]["preciseAmountCents"]).to eq(pricing_unit_usage.precise_amount_cents)
    expect(fee_data["pricingUnitUsage"]["unitAmountCents"]).to eq(pricing_unit_usage.unit_amount_cents.to_s)
    expect(fee_data["pricingUnitUsage"]["conversionRate"]).to eq(pricing_unit_usage.conversion_rate)
    expect(fee_data["pricingUnitUsage"]["shortName"]).to eq(pricing_unit_usage.short_name)
    expect(fee_data["pricingUnitUsage"]["pricingUnit"]["code"]).to eq(pricing_unit.code)
    expect(fee_data["pricingUnitUsage"]["pricingUnit"]["name"]).to eq(pricing_unit.name)
    expect(fee_data["presentationBreakdowns"]).to eq([
      {"presentationBy" => {"department" => "engineering"}, "units" => "60.0"}
    ])
  end

  context "when invoice is not found" do
    it "returns an error" do
      result = execute_graphql(
        current_user: membership.user,
        current_organization: invoice.organization,
        permissions: required_permission,
        query:,
        variables: {
          id: "foo"
        }
      )

      expect_graphql_error(result:, message: "Resource not found")
    end
  end

  context "with a deleted billable metric" do
    let(:billable_metric) { create(:billable_metric, :deleted) }
    let(:billable_metric_filter) { create(:billable_metric_filter, :deleted, billable_metric:) }
    let(:charge_filter) do
      create(:charge_filter, :deleted, charge:, properties: {amount: "10"})
    end
    let(:charge_filter_value) do
      create(
        :charge_filter_value,
        :deleted,
        charge_filter:,
        billable_metric_filter:,
        values: [billable_metric_filter.values.first]
      )
    end
    let(:fee) do
      create(
        :charge_fee,
        subscription:,
        invoice:,
        charge_filter:,
        charge:,
        amount_cents: 10,
        presentation_breakdowns: [build(:presentation_breakdown, organization:)]
      )
    end

    let(:charge) do
      create(:standard_charge, :deleted, billable_metric:)
    end

    it "returns the invoice with the deleted resources" do
      result = execute_graphql(
        current_user: membership.user,
        current_organization: organization,
        permissions: required_permission,
        query:,
        variables: {
          id: invoice.id
        }
      )

      data = result["data"]["invoice"]

      expect(data["id"]).to eq(invoice.id)
      expect(data["number"]).to eq(invoice.number)
      expect(data["paymentStatus"]).to eq(invoice.payment_status)
      expect(data["status"]).to eq(invoice.status)
      expect(data["customer"]["id"]).to eq(customer.id)
      expect(data["customer"]["name"]).to eq(customer.name)
      expect(data["invoiceSubscriptions"][0]["subscription"]["id"]).to eq(subscription.id)
      expect(data["invoiceSubscriptions"][0]["fees"]).to include(a_hash_including("id" => fee.id))
    end
  end

  context "with an add on invoice" do
    let(:invoice) { create(:invoice, customer:, organization:, fees_amount_cents: 10) }
    let(:add_on) { create(:add_on, organization:) }
    let(:applied_add_on) { create(:applied_add_on, add_on:, customer:) }
    let(:fee) do
      create(
        :add_on_fee,
        invoice:,
        applied_add_on:,
        presentation_breakdowns: [build(:presentation_breakdown, organization:)]
      )
    end

    it "returns a single invoice" do
      result = execute_graphql(
        current_user: membership.user,
        current_organization: organization,
        permissions: required_permission,
        query:,
        variables: {
          id: invoice.id
        }
      )

      data = result["data"]["invoice"]

      expect(data["id"]).to eq(invoice.id)
      expect(data["number"]).to eq(invoice.number)
      expect(data["paymentStatus"]).to eq(invoice.payment_status)
      expect(data["status"]).to eq(invoice.status)
      expect(data["customer"]["id"]).to eq(customer.id)
      expect(data["customer"]["name"]).to eq(customer.name)
      add_on_fee = data["fees"].find { |f| f["itemType"] == "add_on" }
      expect(add_on_fee).to include(
        "itemCode" => add_on.code,
        "itemName" => add_on.name
      )
      expect(add_on_fee["presentationBreakdowns"]).to eq([])
    end

    context "with a deleted add_on" do
      let(:add_on) { create(:add_on, :deleted, organization:) }

      it "returns the invoice with the deleted resources" do
        result = execute_graphql(
          current_user: membership.user,
          current_organization: organization,
          permissions: required_permission,
          query:,
          variables: {
            id: invoice.id
          }
        )

        data = result["data"]["invoice"]

        expect(data["id"]).to eq(invoice.id)
        expect(data["number"]).to eq(invoice.number)
        expect(data["paymentStatus"]).to eq(invoice.payment_status)
        expect(data["status"]).to eq(invoice.status)
        expect(data["customer"]["id"]).to eq(customer.id)
        expect(data["customer"]["name"]).to eq(customer.name)
        add_on_fee = data["fees"].find { |f| f["itemType"] == "add_on" }
        expect(add_on_fee).to include(
          "itemCode" => add_on.code,
          "itemName" => add_on.name
        )
        expect(add_on_fee["presentationBreakdowns"]).to eq([])
      end
    end
  end

  context "with a deleted customer" do
    let(:customer) { create(:customer, :deleted, organization:) }

    it "returns the invoice with the deleted customer" do
      result = execute_graphql(
        current_user: membership.user,
        current_organization: organization,
        permissions: required_permission,
        query:,
        variables: {
          id: invoice.id
        }
      )

      data = result["data"]["invoice"]

      expect(data["id"]).to eq(invoice.id)
      expect(data["number"]).to eq(invoice.number)
      expect(data["paymentStatus"]).to eq(invoice.payment_status)
      expect(data["status"]).to eq(invoice.status)
      expect(data["customer"]["id"]).to eq(customer.id)
      expect(data["customer"]["name"]).to eq(customer.name)
      expect(data["customer"]["deletedAt"]).to eq(customer.deleted_at.iso8601)
    end
  end

  context "with a credit invoice" do
    let(:invoice) { create(:invoice, :credit, customer:, organization:) }
    let(:fee) do
      create(
        :credit_fee,
        invoice:,
        invoiceable: wallet_transaction,
        presentation_breakdowns: [build(:presentation_breakdown, organization:)]
      )
    end
    let(:wallet_transaction) { create(:wallet_transaction, organization:, wallet:) }
    let(:wallet) { create(:wallet, organization:, name: "wallet name") }

    before { fee }

    it "returns the invoice with the credit invoice" do
      result = execute_query(query:, variables: {id: invoice.id})

      data = result["data"]["invoice"]
      graphql_wallet_transaction = data.dig("fees", 0, "walletTransaction")
      expect(graphql_wallet_transaction["name"]).to eq("Custom Transaction Name")
      expect(graphql_wallet_transaction["walletName"]).to eq("wallet name")
      expect(data.dig("fees", 0, "presentationBreakdowns")).to eq([])
    end
  end
end
