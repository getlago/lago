# frozen_string_literal: true

# This is a shared example that is used to test the payload of an integration.
# It will test the fallback behavior of the integration from billing entity to organization.
#
# It expects a `build_expected_payload` method to be defined in the spec
# ```
# it_behaves_like "an integration payload", :avalara do
#   def build_expected_payload(mapping_codes, some_extra_parameter_with_defaults: false)
#     [
#       {
#         "issuing_date" => invoice.issuing_date,
#         "currency" => invoice.currency,
#         "some_extra_parameter_with_defaults" => some_extra_parameter_with_defaults,
#         "fees" => match_array([
#           {
#             "item_key" => add_on_fee.item_key,
#             "item_id" => add_on_fee.id,
#             "amount" => "2.0",
#             "unit" => 2.0,
#             "item_code" => mapping_codes.dig(:add_on, :external_id)
#           }
#         ])
#       }
#     ]
#   end
# end
# ```
#
RSpec.shared_examples "an integration payload" do |integration_type|
  let(:integration_type) { integration_type.to_sym }
  let(:mappings_on) { [:billing_entity, :organization] }
  let(:fallback_items_on) { [:billing_entity, :organization] }

  let(:organization) { create(:organization) }
  let(:billing_entity) { create(:billing_entity, organization:) }
  let(:integration) { create("#{integration_type}_integration", organization:) }
  let(:customer) { create(:customer, organization:, billing_entity:) }
  let(:integration_customer) { create("#{integration_type}_customer", customer:, integration:) }

  let(:add_on) { create(:add_on, organization:, name: "Add-on") }
  let(:fixed_charge_add_on) { create(:add_on, organization:, name: "Fixed Charge Add-on") }
  let(:billable_metric) { create(:billable_metric, organization:, name: "Billable Metric") }
  let(:plan) { create(:plan, organization:, name: "Plan") }
  let(:charge) { create(:standard_charge, plan:, organization:, billable_metric:) }
  let(:fixed_charge) { create(:fixed_charge, organization:, plan:, add_on: fixed_charge_add_on) }
  let(:subscription) { create(:subscription, organization:, plan:) }

  let(:invoice) do
    invoice = create(
      :invoice,
      customer:,
      organization:,
      billing_entity:,
      coupons_amount_cents: 200,
      prepaid_credit_amount_cents: 300,
      progressive_billing_credit_amount_cents: 100,
      credit_notes_amount_cents: 500,
      taxes_amount_cents: 300,
      issuing_date: DateTime.new(2024, 7, 8)
    )
    create(:invoice_subscription, invoice:, subscription:)
    invoice
  end
  let(:payment) { create(:payment, payable: invoice) }

  let(:add_on_fee) { create(:add_on_fee, invoice:, add_on:, units: 2, amount_cents: 200, precise_unit_amount: 100.0, invoice_display_name: "Add-on Fee") }
  let(:billable_metric_fee) { create(:charge_fee, invoice:, billable_metric:, units: 3, amount_cents: 300, charge:, invoice_display_name: "Standard Charge Fee", precise_unit_amount: 100.0) }
  let(:minimum_commitment_fee) { create(:minimum_commitment_fee, invoice:, units: 4, amount_cents: 400, invoice_display_name: "Minimum Commitment Fee", precise_unit_amount: 100.0) }
  let(:subscription_fee) { create(:fee, invoice:, subscription:, units: 5, amount_cents: 500, precise_unit_amount: 100.0) }
  let(:fixed_charge_fee) { create(:fixed_charge_fee, invoice:, fixed_charge:, units: 6, amount_cents: 150, precise_unit_amount: 25.0, invoice_display_name: "Fixed Charge Fee") }
  let(:fees) { invoice.fees }

  let(:credit_note) { create(:credit_note, customer:, invoice:, issuing_date: DateTime.new(2024, 7, 8)) }

  let(:add_on_credit_note_item) { create(:credit_note_item, credit_note:, fee: add_on_fee, amount_cents: 190) }
  let(:billable_metric_credit_note_item) { create(:credit_note_item, credit_note:, fee: billable_metric_fee, amount_cents: 180) }
  let(:minimum_commitment_credit_note_item) { create(:credit_note_item, credit_note:, fee: minimum_commitment_fee, amount_cents: 170) }
  let(:subscription_credit_note_item) { create(:credit_note_item, credit_note:, fee: subscription_fee, amount_cents: 160) }
  let(:fixed_charge_credit_note_item) { create(:credit_note_item, credit_note:, fee: fixed_charge_fee, amount_cents: 140) }

  let(:add_on_mapping_on_billing_entity) do
    settings = {external_id: "add_on_on_billing_entity", external_account_code: "11", external_name: "add_on_on_billing_entity"}
    create_mapping("AddOn", add_on.id, billing_entity:, settings:)
  end
  let(:fixed_charge_add_on_mapping_on_billing_entity) do
    settings = {external_id: "fixed_charge_on_billing_entity", external_account_code: "21", external_name: "fixed_charge_on_billing_entity"}
    create_mapping("AddOn", fixed_charge_add_on.id, billing_entity:, settings:)
  end
  let(:billable_metric_mapping_on_billing_entity) do
    settings = {external_id: "billable_metric_on_billing_entity", external_account_code: "12", external_name: "billable_metric_on_billing_entity"}
    create_mapping("BillableMetric", billable_metric.id, billing_entity:, settings:)
  end
  let(:commitment_mapping_on_billing_entity) do
    settings = {external_id: "commitment_on_billing_entity", external_account_code: "13", external_name: "commitment_on_billing_entity"}
    create_collection_mapping(:minimum_commitment, billing_entity:, settings:)
  end
  let(:subscription_mapping_on_billing_entity) do
    settings = {external_id: "subscription_on_billing_entity", external_account_code: "14", external_name: "subscription_on_billing_entity"}
    create_collection_mapping(:subscription_fee, billing_entity:, settings:)
  end
  let(:account_mapping_on_billing_entity) do
    settings = {external_id: "account_on_billing_entity", external_account_code: "15", external_name: "account_on_billing_entity"}
    create_collection_mapping(:account, billing_entity:, settings:)
  end
  let(:credit_note_mapping_on_billing_entity) do
    settings = {external_id: "credit_note_on_billing_entity", external_account_code: "16", external_name: "credit_note_on_billing_entity"}
    create_collection_mapping(:credit_note, billing_entity:, settings:)
  end
  let(:prepaid_credit_mapping_on_billing_entity) do
    settings = {external_id: "prepaid_credit_on_billing_entity", external_account_code: "17", external_name: "prepaid_credit_on_billing_entity"}
    create_collection_mapping(:prepaid_credit, billing_entity:, settings:)
  end
  let(:tax_mapping_on_billing_entity) do
    settings = {external_id: "tax_on_billing_entity", external_account_code: "18", external_name: "tax_on_billing_entity"}
    create_collection_mapping(:tax, billing_entity:, settings:)
  end
  let(:coupon_mapping_on_billing_entity) do
    settings = {external_id: "coupon_on_billing_entity", external_account_code: "19", external_name: "coupon_on_billing_entity"}
    create_collection_mapping(:coupon, billing_entity:, settings:)
  end
  let(:fallback_item_on_billing_entity) do
    settings = {external_id: "fallback_item_on_billing_entity", external_account_code: "20", external_name: "fallback_item_on_billing_entity"}
    create_collection_mapping(:fallback_item, billing_entity:, settings:)
  end

  let(:add_on_mapping_on_organization) do
    settings = {external_id: "add_on_on_organization", external_account_code: "111", external_name: "add_on_on_organization"}
    create_mapping("AddOn", add_on.id, billing_entity: nil, settings:)
  end
  let(:fixed_charge_add_on_mapping_on_organization) do
    settings = {external_id: "fixed_charge_on_organization", external_account_code: "121", external_name: "fixed_charge_on_organization"}
    create_mapping("AddOn", fixed_charge_add_on.id, billing_entity: nil, settings:)
  end
  let(:billable_metric_mapping_on_organization) do
    settings = {external_id: "billable_metric_on_organization", external_account_code: "112", external_name: "billable_metric_on_organization"}
    create_mapping("BillableMetric", billable_metric.id, billing_entity: nil, settings:)
  end
  let(:commitment_mapping_on_organization) do
    settings = {external_id: "commitment_on_organization", external_account_code: "113", external_name: "commitment_on_organization"}
    create_collection_mapping(:minimum_commitment, billing_entity: nil, settings:)
  end
  let(:subscription_mapping_on_organization) do
    settings = {external_id: "subscription_on_organization", external_account_code: "114", external_name: "subscription_on_organization"}
    create_collection_mapping(:subscription_fee, billing_entity: nil, settings:)
  end
  let(:account_mapping_on_organization) do
    settings = {external_id: "account_on_organization", external_account_code: "115", external_name: "account_on_organization"}
    create_collection_mapping(:account, billing_entity: nil, settings:)
  end
  let(:credit_note_mapping_on_organization) do
    settings = {external_id: "credit_note_on_organization", external_account_code: "116", external_name: "credit_note_on_organization"}
    create_collection_mapping(:credit_note, billing_entity: nil, settings:)
  end
  let(:prepaid_credit_mapping_on_organization) do
    settings = {external_id: "prepaid_credit_on_organization", external_account_code: "117", external_name: "prepaid_credit_on_organization"}
    create_collection_mapping(:prepaid_credit, billing_entity: nil, settings:)
  end
  let(:tax_mapping_on_organization) do
    settings = {external_id: "tax_on_organization", external_account_code: "118", external_name: "tax_on_organization"}
    create_collection_mapping(:tax, billing_entity: nil, settings:)
  end
  let(:coupon_mapping_on_organization) do
    settings = {external_id: "coupon_on_organization", external_account_code: "119", external_name: "coupon_on_organization"}
    create_collection_mapping(:coupon, billing_entity: nil, settings:)
  end
  let(:fallback_item_on_organization) do
    settings = {external_id: "fallback_item_on_organization", external_account_code: "120", external_name: "fallback_item_on_organization"}
    create_collection_mapping(:fallback_item, billing_entity: nil, settings:)
  end

  let(:default_mapping_codes) do
    {
      add_on: {external_id: "add_on_on_billing_entity", external_account_code: "11", external_name: "add_on_on_billing_entity"},
      fixed_charge: {external_id: "fixed_charge_on_billing_entity", external_account_code: "21", external_name: "fixed_charge_on_billing_entity"},
      billable_metric: {external_id: "billable_metric_on_billing_entity", external_account_code: "12", external_name: "billable_metric_on_billing_entity"},
      minimum_commitment: {external_id: "commitment_on_billing_entity", external_account_code: "13", external_name: "commitment_on_billing_entity"},
      subscription: {external_id: "subscription_on_billing_entity", external_account_code: "14", external_name: "subscription_on_billing_entity"},
      account: {external_id: "account_on_billing_entity", external_account_code: "15", external_name: "account_on_billing_entity"},
      credit_note: {external_id: "credit_note_on_billing_entity", external_account_code: "16", external_name: "credit_note_on_billing_entity"},
      prepaid_credit: {external_id: "prepaid_credit_on_billing_entity", external_account_code: "17", external_name: "prepaid_credit_on_billing_entity"},
      tax: {external_id: "tax_on_billing_entity", external_account_code: "18", external_name: "tax_on_billing_entity"},
      coupon: {external_id: "coupon_on_billing_entity", external_account_code: "19", external_name: "coupon_on_billing_entity"},
      fallback_item: {external_id: "fallback_item_on_billing_entity", external_account_code: "20", external_name: "fallback_item_on_billing_entity"}
    }
  end

  before do
    add_on_mapping_on_billing_entity
    fixed_charge_add_on_mapping_on_billing_entity
    billable_metric_mapping_on_billing_entity
    commitment_mapping_on_billing_entity
    subscription_mapping_on_billing_entity
    account_mapping_on_billing_entity
    credit_note_mapping_on_billing_entity
    prepaid_credit_mapping_on_billing_entity
    tax_mapping_on_billing_entity
    coupon_mapping_on_billing_entity

    add_on_mapping_on_organization
    fixed_charge_add_on_mapping_on_organization
    billable_metric_mapping_on_organization
    commitment_mapping_on_organization
    subscription_mapping_on_organization
    account_mapping_on_organization
    credit_note_mapping_on_organization
    prepaid_credit_mapping_on_organization
    tax_mapping_on_organization
    coupon_mapping_on_organization

    fallback_item_on_billing_entity

    fallback_item_on_organization

    integration_customer
    add_on_credit_note_item
    fixed_charge_credit_note_item
    billable_metric_credit_note_item
    minimum_commitment_credit_note_item
    subscription_credit_note_item
    credit_note.reload

    payment
  end

  def skip_mapping?(billing_entity)
    create_mapping_for_billing_entity = (billing_entity.present? && mappings_on.include?(:billing_entity)) ||
      (billing_entity.blank? && mappings_on.include?(:organization))
    !create_mapping_for_billing_entity
  end

  def skip_fallback_item?(billing_entity)
    create_fallback_items_for_billing_entity = (billing_entity.present? && fallback_items_on.include?(:billing_entity)) ||
      (billing_entity.blank? && fallback_items_on.include?(:organization))
    !create_fallback_items_for_billing_entity
  end

  def create_mapping(mappable_type, mappable_id, billing_entity: nil, settings: {})
    return if skip_mapping?(billing_entity)

    create("#{integration_type}_mapping", integration:, mappable_type:, mappable_id:, billing_entity:, settings:)
  end

  def create_collection_mapping(mapping_type, billing_entity: nil, settings: {})
    return if mapping_type == :fallback_item && skip_fallback_item?(billing_entity)
    return if mapping_type != :fallback_item && skip_mapping?(billing_entity)

    create("#{integration_type}_collection_mapping", integration:, billing_entity:, mapping_type:, settings:)
  end

  context "when the mapping is on the billing entity" do
    it "returns the payload body" do
      expect(payload).to match build_expected_payload(default_mapping_codes)
    end
  end

  context "when the mapping is not on the billing entity but there are fallback items" do
    let(:mappings_on) { [:organization] }
    let(:fallback_items_on) { [:billing_entity] }

    it "returns the payload body" do
      fallback = {external_id: "fallback_item_on_billing_entity", external_account_code: "20", external_name: "fallback_item_on_billing_entity"}
      expect(payload).to match build_expected_payload({
        add_on: fallback,
        fixed_charge: fallback,
        billable_metric: fallback,
        minimum_commitment: fallback,
        subscription: fallback,
        account: fallback,
        credit_note: fallback,
        prepaid_credit: fallback,
        tax: fallback,
        coupon: fallback
      })
    end
  end

  context "when the mapping is only on the organization" do
    let(:mappings_on) { [:organization] }
    let(:fallback_items_on) { [:organization] }

    it "returns the payload body" do
      expect(payload).to match build_expected_payload({
        add_on: {external_id: "add_on_on_organization", external_account_code: "111", external_name: "add_on_on_organization"},
        fixed_charge: {external_id: "fixed_charge_on_organization", external_account_code: "121", external_name: "fixed_charge_on_organization"},
        billable_metric: {external_id: "billable_metric_on_organization", external_account_code: "112", external_name: "billable_metric_on_organization"},
        minimum_commitment: {external_id: "commitment_on_organization", external_account_code: "113", external_name: "commitment_on_organization"},
        subscription: {external_id: "subscription_on_organization", external_account_code: "114", external_name: "subscription_on_organization"},
        account: {external_id: "account_on_organization", external_account_code: "115", external_name: "account_on_organization"},
        credit_note: {external_id: "credit_note_on_organization", external_account_code: "116", external_name: "credit_note_on_organization"},
        prepaid_credit: {external_id: "prepaid_credit_on_organization", external_account_code: "117", external_name: "prepaid_credit_on_organization"},
        tax: {external_id: "tax_on_organization", external_account_code: "118", external_name: "tax_on_organization"},
        coupon: {external_id: "coupon_on_organization", external_account_code: "119", external_name: "coupon_on_organization"}
      })
    end
  end

  context "when there are only fallback items on the organization" do
    let(:mappings_on) { [] }
    let(:fallback_items_on) { [:organization] }

    it "returns the payload body" do
      fallback = {external_id: "fallback_item_on_organization", external_account_code: "120", external_name: "fallback_item_on_organization"}
      expect(payload).to match build_expected_payload({
        add_on: fallback,
        fixed_charge: fallback,
        billable_metric: fallback,
        minimum_commitment: fallback,
        subscription: fallback,
        account: fallback,
        credit_note: fallback,
        prepaid_credit: fallback,
        tax: fallback,
        coupon: fallback
      })
    end
  end
end
