# frozen_string_literal: true

require "rails_helper"

RSpec.describe Resolvers::InvoiceBuildRegenerationPreviewResolver do
  let(:required_permission) { "invoices:view" }
  let(:query) do
    <<~GQL
      query($id: ID!) {
        invoiceBuildRegenerationPreview(id: $id) {
          id
          invoiceType
          number
          paymentStatus
          status
          taxStatus
          totalAmountCents
          currency
          refundableAmountCents
          creditableAmountCents
          offsettableAmountCents
          voidable
          paymentDisputeLostAt
          paymentDisputeLosable
          integrationSyncable
          externalIntegrationId
          taxProviderId
          taxProviderVoidable
          integrationHubspotSyncable
          externalHubspotIntegrationId
          integrationSalesforceSyncable
          externalSalesforceIntegrationId
          associatedActiveWalletPresent
          xmlUrl
          voidedAt
          voidedInvoiceId
          regeneratedInvoiceId
          expectedFinalizationDate
          subTotalExcludingTaxesAmountCents
          subTotalIncludingTaxesAmountCents
          totalDueAmountCents
          totalSettledAmountCents
          totalPaidAmountCents
          couponsAmountCents
          creditNotesAmountCents
          prepaidCreditAmountCents
          prepaidGrantedCreditAmountCents
          prepaidPurchasedCreditAmountCents
          progressiveBillingCreditAmountCents
          feesAmountCents
          issuingDate
          paymentDueDate
          paymentOverdue
          allChargesHaveFees
          allFixedChargesHaveFees
          versionNumber
          taxesRate
          errorDetails {
            errorCode
            errorDetails
          }
          billingEntity {
            id
            name
            code
            email
            einvoicing
            emailSettings
            logoUrl
          }
          customer {
            id
            email
            name
            displayName
            legalNumber
            legalName
            taxIdentificationNumber
            addressLine1
            addressLine2
            state
            country
            city
            zipcode
            applicableTimezone
            deletedAt
            accountType
          }
          subscriptions {
            id
            name
            currentBillingPeriodStartedAt
            currentBillingPeriodEndingAt
            plan {
              id
              name
              interval
            }
          }
          invoiceSubscriptions {
            subscription {
              id
            }
            invoice {
              id
            }
            acceptNewChargeFees
          }
          appliedTaxes {
            id
            amountCents
            feesAmountCents
            taxableAmountCents
            taxRate
            taxCode
            taxName
            enumedTaxCode
            taxDescription
            amountCurrency
          }
          fees {
            id
            invoiceId
            succeededAt
            amountCents
            currency
            preciseUnitAmount
            adjustedFee
            adjustedFeeType
            eventsCount
            description
            feeType
            itemType
            itemCode
            itemName
            invoiceName
            invoiceDisplayName
            units
            groupedBy
            creditableAmountCents
            taxesRate
            addOn {
              id
            }
            trueUpParentFee {
              id
            }
            walletTransaction {
              id
              name
              wallet {
                id
                name
              }
            }
            properties {
              fromDatetime
              toDatetime
            }
            pricingUnitUsage {
              amountCents
              conversionRate
              shortName
              preciseUnitAmount
            }
            appliedTaxes {
              id
              taxCode
              taxName
              taxRate
              taxDescription
              amountCents
              amountCurrency
              tax {
                id
                name
                code
                rate
              }
            }
            amountDetails {
              freeUnits
              fixedFeeUnitAmount
              fixedFeeTotalAmount
              flatUnitAmount
              freeEvents
              paidEvents
              freeUnits
              paidUnits
              minMaxAdjustmentTotalAmount
              perPackageSize
              perPackageUnitAmount
              perUnitAmount
              perUnitTotalAmount
              perUnitTotalAmount
              rate
              units
              graduatedRanges {
                flatUnitAmount
                fromValue
                perUnitAmount
                perUnitTotalAmount
                toValue
                totalWithFlatAmount
                units
              }
              graduatedPercentageRanges {
                flatUnitAmount
                fromValue
                perUnitTotalAmount
                rate
                toValue
                totalWithFlatAmount
                units
              }
            }
            charge {
              id
              payInAdvance
              minAmountCents
              chargeModel
              prorated
              billableMetric {
                id
                name
                recurring
                aggregationType
                code
                filters { key values }
              }
              filters { invoiceDisplayName values }
            }
            chargeFilter {
              id
              invoiceDisplayName
              values
            }
            subscription {
              id
              plan {
                id
                interval
                name
              }
            }
            fixedCharge {
              id
              chargeModel
              prorated
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
  let(:invoice) { create(:invoice, customer:, organization:, fees_amount_cents: 10, taxes_rate: 15) }
  let(:subscription) { invoice_subscription.subscription }
  let(:billable_metric) { create(:billable_metric, organization:) }
  let(:charge) { create(:standard_charge, plan: subscription.plan) }
  let(:add_on) { create(:add_on, organization:) }
  let(:fee) do
    create(:fee, subscription:, invoice:, amount_cents: 50)
  end
  let(:charge_fee) do
    create(:charge_fee, subscription:, invoice:, amount_cents: 250, charge:)
  end
  let(:fixed_charge) { create(:fixed_charge, plan: subscription.plan) }
  let(:fixed_charge_fee) do
    create(:fixed_charge_fee, subscription:, invoice:, amount_cents: 150, fixed_charge:)
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

    data = result["data"]["invoiceBuildRegenerationPreview"]

    expect(data["id"]).to eq(invoice.id)
    expect(data["number"]).to eq(invoice.number)
    expect(data["paymentStatus"]).to eq(invoice.payment_status)
    expect(data["paymentDisputeLosable"]).to eq(true)
    expect(data["status"]).to eq(invoice.status)
    expect(data["taxesRate"]).to eq(0)
    expect(data["customer"]["id"]).to eq(customer.id)
    expect(data["customer"]["name"]).to eq(customer.name)

    expect(data["appliedTaxes"]).to be_empty

    subscription_fee = data["fees"].find { |f| f["itemType"] == "subscription" }
    expect(subscription_fee["id"]).to eq(fee.id)
    expect(subscription_fee["taxesRate"]).to eq(0)

    invoice_charge_fee = data["fees"].find { |f| f["itemType"] == "charge" }
    expect(invoice_charge_fee["id"]).to eq(charge_fee.id)
    expect(invoice_charge_fee["taxesRate"]).to eq(0)

    invoice_charge_fee = data["fees"].find { |f| f["itemType"] == "charge" }
    expect(invoice_charge_fee["id"]).to eq(charge_fee.id)
    expect(invoice_charge_fee["taxesRate"]).to eq(0)

    invoice_fixed_charge_fee = data["fees"].find { |f| f["itemType"] == "fixed_charge" }
    expect(invoice_fixed_charge_fee["id"]).to eq(fixed_charge_fee.id)
    expect(invoice_fixed_charge_fee["taxesRate"]).to eq(0)
  end

  context "when taxes apply to regenerated fees" do
    let(:tax) { create(:tax, organization:, code: "vat", description: "VAT 20", name: "VAT", rate: 20.0) }

    before do
      create(:billing_entity_applied_tax, billing_entity: customer.billing_entity, organization:, tax:)
    end

    it "returns applied taxes on the invoice and each fee" do
      result = execute_graphql(
        current_user: membership.user,
        current_organization: organization,
        permissions: required_permission,
        query:,
        variables: {
          id: invoice.id
        }
      )

      data = result["data"]["invoiceBuildRegenerationPreview"]

      expect(data["taxesRate"]).to eq(20.0)
      expect(data["appliedTaxes"]).to contain_exactly(
        include(
          "amountCents" => "90",
          "feesAmountCents" => "450",
          "taxableAmountCents" => "450",
          "taxCode" => tax.code,
          "taxDescription" => tax.description,
          "taxName" => tax.name,
          "taxRate" => tax.rate
        )
      )

      expect(data["fees"].map { |fee_data| fee_data["id"] }).to match_array([fee.id, charge_fee.id, fixed_charge_fee.id])

      expected_fee_taxes = {
        fee.id => "10",
        charge_fee.id => "50",
        fixed_charge_fee.id => "30"
      }

      data["fees"].each do |fee_data|
        expect(fee_data["taxesRate"]).to eq(20.0)
        expect(fee_data["appliedTaxes"]).to contain_exactly(
          include(
            "amountCents" => expected_fee_taxes[fee_data["id"]],
            "taxCode" => tax.code,
            "taxDescription" => tax.description,
            "taxName" => tax.name,
            "taxRate" => tax.rate,
            "tax" => include(
              "id" => tax.id,
              "name" => tax.name,
              "code" => tax.code,
              "rate" => tax.rate
            )
          )
        )
      end
    end
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
end
