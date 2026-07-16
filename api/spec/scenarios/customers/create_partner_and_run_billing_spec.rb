# frozen_string_literal: true

require "rails_helper"

describe "Create partner and run billing Scenarios", :premium do
  let(:organization) { create(:organization, webhook_url: nil, document_numbering: "per_organization", premium_integrations: ["revenue_share"]) }
  let(:billing_entity) { organization.default_billing_entity }
  let(:partner) { create(:customer, organization:, billing_entity:) }
  let(:customers) { create_list(:customer, 2, organization:, billing_entity:) }
  let(:plan) { create(:plan, organization:) }
  let(:metric) { create(:latest_billable_metric, organization:) }
  let(:params) do
    {code: metric.code, transaction_id: SecureRandom.uuid}
  end

  before do
    billing_entity.update!(document_numbering: "per_billing_entity")
  end

  it "allows to switch customer to partner before customer has assigned plans" do
    expect do
      create_or_update_customer(
        {
          external_id: partner.external_id,
          account_type: "partner"
        }
      )
      partner.reload
    end.to change(partner, :account_type).from("customer").to("partner")
      .and change(partner, :exclude_from_dunning_campaign).from(false).to(true)

    create_subscription(
      {
        external_customer_id: partner.external_id,
        external_id: partner.external_id,
        plan_code: plan.code
      }
    )

    expect do
      create_or_update_customer(
        {
          external_id: partner.external_id,
          account_type: "customer"
        }
      )
    end.not_to change(partner.reload, :account_type)
  end

  it "creates partner-specific invoices without payments, with partner numbering, excluded from analytics" do
    create_or_update_customer(
      {
        external_id: partner.external_id,
        account_type: "partner"
      }
    )

    ### 24 Apr: Create subscriptions + charges.
    apr24 = Time.zone.parse("2024-04-24")
    travel_to(apr24) do
      create(
        :package_charge,
        plan: plan,
        billable_metric: metric,
        pay_in_advance: false,
        prorated: false,
        invoiceable: true,
        properties: {
          amount: "2",
          free_units: 1000,
          package_size: 1000
        }
      )

      customers.each do |customer|
        create_subscription(
          {
            external_customer_id: customer.external_id,
            external_id: customer.external_id,
            plan_code: plan.code
          }
        )
      end
      create_subscription(
        {
          external_customer_id: partner.external_id,
          external_id: partner.external_id,
          plan_code: plan.code
        }
      )
    end

    ### 25 Apr: Ingest events for Plan 1.
    apr24 = Time.zone.parse("2024-04-24")
    travel_to(apr24) do
      plan.subscriptions.each do |subscription|
        create_event(
          params.merge(
            external_subscription_id: subscription.external_id
          )
        )
      end
      perform_all_enqueued_jobs
    end

    # May 1st: Billing run; check invoice numbering
    may1 = Time.zone.parse("2024-05-01")
    travel_to(may1) do
      organization.update!(created_at: 1.month.ago)
      perform_billing
      expect(billing_entity.invoices.count).to eq(3)
      expect(partner.invoices.count).to eq(1)

      perform_billing
      expect(billing_entity.invoices.count).to eq(3)
      expect(partner.invoices.count).to eq(1)

      partner_invoice = partner.invoices.first
      expect(partner_invoice.self_billed).to eq(true)
      expect(partner_invoice.number).to eq("#{billing_entity.document_number_prefix}-001-001")

      customers_invoices = customers.map(&:invoices).flatten
      expect(customers_invoices.map(&:self_billed)).not_to include(true)
      expect(customers_invoices.map do |inv|
        inv.number.gsub("#{billing_entity.document_number_prefix}-202405-", "")
      end.uniq.sort).to eq(["001", "002"])
    end

    # June 1st: Billing run; check invoice numbering
    june1 = Time.zone.parse("2024-06-01")
    travel_to(june1) do
      perform_billing
      expect(billing_entity.invoices.count).to eq(6)
      expect(partner.invoices.count).to eq(2)

      partner_invoice = partner.invoices.where(created_at: june1).first
      expect(partner_invoice.self_billed).to eq(true)
      expect(partner_invoice.number).to eq("#{billing_entity.document_number_prefix}-001-002")

      customers_invoices = customers.map { |c| c.invoices.where(created_at: june1) }.flatten
      expect(customers_invoices.map(&:self_billed).uniq).to eq([false])
      expect(customers_invoices.map do |inv|
        inv.number.gsub("#{billing_entity.document_number_prefix}-202406-", "")
      end.uniq.sort).to eq(["003", "004"])
    end
    perform_overdue_balance_update

    # check payments
    expect(partner.invoices.map(&:payments).flatten).to be_empty

    # check analytics
    may_org_invoices = organization.invoices.where(self_billed: false, created_at: may1)
    june_org_invoices = organization.invoices.where(self_billed: false, created_at: june1)

    months = (Time.zone.now.beginning_of_month - Time.zone.parse("2024-04-01")).second.in_months.round + 1

    # invoice_collection
    get_analytics(organization:, analytics_type: "invoice_collection", months:)
    collection = json[:invoice_collections]
    may_stats = collection.find { |el| el[:month] == "2024-05-01T00:00:00.000Z" }
    june_stats = collection.find { |el| el[:month] == "2024-06-01T00:00:00.000Z" }

    expect(may_stats[:invoices_count]).to eq(2)
    expect(may_stats[:amount_cents]).to eq(may_org_invoices.sum(:sub_total_including_taxes_amount_cents))
    expect(june_stats[:invoices_count]).to eq(2)
    expect(june_stats[:amount_cents]).to eq(june_org_invoices.sum(:sub_total_including_taxes_amount_cents))

    # gross_revenue
    get_analytics(organization:, analytics_type: "gross_revenue", months:)
    collection = json[:gross_revenues]
    may_stats = collection.find { |el| el[:month] == "2024-05-01T00:00:00.000Z" }
    june_stats = collection.find { |el| el[:month] == "2024-06-01T00:00:00.000Z" }

    expect(may_stats[:invoices_count].to_i).to eq(2)
    expect(may_stats[:amount_cents]).to eq(may_org_invoices.sum(:sub_total_including_taxes_amount_cents))
    expect(june_stats[:invoices_count].to_i).to eq(2)
    expect(june_stats[:amount_cents]).to eq(june_org_invoices.sum(:sub_total_including_taxes_amount_cents))

    # mrr
    get_analytics(organization:, analytics_type: "mrr", months:)
    collection = json[:mrrs]
    # We have different time format for mrr - is it alright?
    may_stats = collection.find { |el| el[:month] == "2024-05-01T00:00:00.000+00:00" }
    june_stats = collection.find { |el| el[:month] == "2024-06-01T00:00:00.000+00:00" }

    expect(may_stats[:amount_cents].to_i).to eq(may_org_invoices.sum(:sub_total_including_taxes_amount_cents))
    expect(june_stats[:amount_cents].to_i).to eq(june_org_invoices.sum(:sub_total_including_taxes_amount_cents))

    # overdue_balance
    get_analytics(organization:, analytics_type: "overdue_balance", months:)
    collection = json[:overdue_balances]
    may_stats = collection.find { |el| el[:month] == "2024-05-01T00:00:00.000Z" }
    june_stats = collection.find { |el| el[:month] == "2024-06-01T00:00:00.000Z" }

    expect(may_stats[:lago_invoice_ids].sort).to match(may_org_invoices.map(&:id).sort)
    expect(may_stats[:amount_cents].to_i).to eq(may_org_invoices.sum(:sub_total_including_taxes_amount_cents))
    expect(june_stats[:lago_invoice_ids].sort).to match(june_org_invoices.map(&:id).sort)
    expect(june_stats[:amount_cents].to_i).to eq(june_org_invoices.sum(:sub_total_including_taxes_amount_cents))
  end
end
