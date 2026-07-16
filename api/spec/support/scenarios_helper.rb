# frozen_string_literal: true

module ScenariosHelper
  def api_call(perform_jobs: true, raise_on_error: true)
    yield

    if raise_on_error && response.status >= 400
      request = response.request
      message_parts = ["API call failed:",
        "- Method: #{request.method}",
        "- Path: #{request.path}",
        "- Request body: #{request.body.read}",
        "- HTTP status: #{response.status}",
        "- Response body: #{response.body}"]
      message = message_parts.join("\n")
      raise message
    end

    perform_all_enqueued_jobs if perform_jobs
    json.with_indifferent_access
  end

  def clock_job
    yield
    perform_all_enqueued_jobs
  end

  ### Organizations

  def update_organization(params, **kwargs)
    api_call(**kwargs) do
      put_with_token(organization, "/api/v1/organizations", {organization: params})
    end
  end

  ### Billing entities

  def update_billing_entity(billing_entity, params)
    # TODO: use the endpoint to update the billing entity instead when available
    BillingEntities::UpdateService.call!(billing_entity: billing_entity.reload, params:)
  end

  ### Billable metrics

  def create_metric(params, **kwargs)
    api_call(**kwargs) do
      post_with_token(organization, "/api/v1/billable_metrics", {billable_metric: params})
    end
  end

  def update_metric(metric, params, **kwargs)
    api_call(**kwargs) do
      put_with_token(organization, "/api/v1/billable_metrics/#{metric.code}", {billable_metric: params})
    end
  end

  ### Customers

  def create_or_update_customer(params, **kwargs)
    api_call(**kwargs) do
      post_with_token(organization, "/api/v1/customers", {customer: params})
    end
  end

  def delete_customer(customer, **kwargs)
    api_call(**kwargs) do
      delete_with_token(organization, "/api/v1/customers/#{customer.external_id}")
    end
  end

  def fetch_current_usage(customer:, subscription: customer.subscriptions.first, **kwargs)
    api_call(**kwargs) do
      url = "/api/v1/customers/#{customer.external_id}/current_usage?external_subscription_id=#{subscription.external_id}"
      get_with_token(organization, url)
    end
  end

  ### Plans

  def create_plan(params, **kwargs)
    api_call(**kwargs) do
      post_with_token(organization, "/api/v1/plans", {plan: params})
    end
  end

  def update_plan(plan, params, **kwargs)
    api_call(**kwargs) do
      put_with_token(organization, "/api/v1/plans/#{plan.code}", {plan: params})
    end
  end

  def delete_plan(plan, **kwargs)
    api_call(**kwargs) do
      delete_with_token(organization, "/api/v1/plans/#{plan.code}")
    end
  end

  ### Plan Charges

  def create_plan_charge(plan, params, **kwargs)
    api_call(**kwargs) do
      post_with_token(organization, "/api/v1/plans/#{plan.code}/charges", {charge: params})
    end
  end

  def update_plan_charge(plan, charge_code, params, **kwargs)
    api_call(**kwargs) do
      put_with_token(organization, "/api/v1/plans/#{plan.code}/charges/#{charge_code}", {charge: params})
    end
  end

  def delete_plan_charge(plan, charge_code, **kwargs)
    api_call(**kwargs) do
      delete_with_token(organization, "/api/v1/plans/#{plan.code}/charges/#{charge_code}")
    end
  end

  ### Plan Charge Filters

  def create_plan_charge_filter(plan, charge_code, params, **kwargs)
    api_call(**kwargs) do
      post_with_token(organization, "/api/v1/plans/#{plan.code}/charges/#{charge_code}/filters", {filter: params})
    end
  end

  def update_plan_charge_filter(plan, charge_code, filter_id, params, **kwargs)
    api_call(**kwargs) do
      put_with_token(organization, "/api/v1/plans/#{plan.code}/charges/#{charge_code}/filters/#{filter_id}", {filter: params})
    end
  end

  def delete_plan_charge_filter(plan, charge_code, filter_id, **kwargs)
    api_call(**kwargs) do
      delete_with_token(organization, "/api/v1/plans/#{plan.code}/charges/#{charge_code}/filters/#{filter_id}")
    end
  end

  ### Subscriptions

  def create_subscription(params, authorization = nil, as: :json, **kwargs)
    payload = {subscription: params}
    payload[:authorization] = authorization if authorization
    api_call(**kwargs) do
      post_with_token(organization, "/api/v1/subscriptions", payload)
    end
    parse_result(as, Subscription, :subscription)
  end

  def update_subscription(subscription, params, **kwargs)
    api_call(**kwargs) do
      put_with_token(organization, "/api/v1/subscriptions/#{subscription.external_id}", {subscription: params})
    end
  end

  def terminate_subscription(subscription, params: {}, **kwargs)
    api_call(**kwargs) do
      delete_with_token(organization, "/api/v1/subscriptions/#{subscription.external_id}?#{params.to_query}")
    end
  end

  ### Subscription Charges

  def update_subscription_charge(subscription, charge_code, params, **kwargs)
    api_call(**kwargs) do
      put_with_token(organization, "/api/v1/subscriptions/#{subscription.external_id}/charges/#{charge_code}", {charge: params})
    end
  end

  ### Subscription Fixed Charges

  def update_subscription_fixed_charge(subscription, fixed_charge_code, params, **kwargs)
    api_call(**kwargs) do
      put_with_token(organization, "/api/v1/subscriptions/#{subscription.external_id}/fixed_charges/#{fixed_charge_code}", {fixed_charge: params})
    end
  end

  ### Subscription Charge Filters

  def create_subscription_charge_filter(subscription, charge_code, params, **kwargs)
    api_call(**kwargs) do
      post_with_token(organization, "/api/v1/subscriptions/#{subscription.external_id}/charges/#{charge_code}/filters", {filter: params})
    end
  end

  def update_subscription_charge_filter(subscription, charge_code, filter_id, params, **kwargs)
    api_call(**kwargs) do
      put_with_token(organization, "/api/v1/subscriptions/#{subscription.external_id}/charges/#{charge_code}/filters/#{filter_id}", {filter: params})
    end
  end

  def delete_subscription_charge_filter(subscription, charge_code, filter_id, **kwargs)
    api_call(**kwargs) do
      delete_with_token(organization, "/api/v1/subscriptions/#{subscription.external_id}/charges/#{charge_code}/filters/#{filter_id}")
    end
  end

  def create_alert(sub_external_id, params, **kwargs)
    api_call(**kwargs) do
      post_with_token(organization, "/api/v1/subscriptions/#{sub_external_id}/alerts", {alert: params})
    end
  end

  def create_wallet_alert(customer_external_id, wallet_code, params, as: :json, **kwargs)
    api_call(**kwargs) do
      post_with_token(
        organization,
        "/api/v1/customers/#{customer_external_id}/wallets/#{wallet_code}/alerts",
        {alert: params}
      )
    end
    parse_result(as, UsageMonitoring::Alert, :alert)
  end

  ### Invoices

  def refresh_invoice(invoice, **kwargs)
    api_call(**kwargs) do
      put_with_token(organization, "/api/v1/invoices/#{invoice.id}/refresh", {})
    end
  end

  def finalize_invoice(invoice, **kwargs)
    api_call(**kwargs) do
      put_with_token(organization, "/api/v1/invoices/#{invoice.id}/finalize", {})
    end
  end

  def update_invoice(invoice, params, **kwargs)
    api_call(**kwargs) do
      put_with_token(organization, "/api/v1/invoices/#{invoice.id}", {invoice: params})
    end
  end

  def void_invoice(invoice, params = {})
    post_with_token(organization, "/api/v1/invoices/#{invoice.id}/void", params)
    perform_all_enqueued_jobs
    invoice.reload
  end

  def create_one_off_invoice(customer, addons, taxes: [], currency: "EUR", units: 1, **kwargs)
    api_call(**kwargs) do
      create_invoice_params = {
        external_customer_id: customer.external_id,
        currency:,
        fees: [],
        timestamp: Time.zone.now.to_i
      }
      addons.each do |fee|
        fee_addon_params = {
          add_on_id: fee.id,
          add_on_code: fee.code,
          name: fee.name,
          units:,
          unit_amount_cents: fee.amount_cents,
          tax_codes: taxes
        }
        create_invoice_params[:fees].push(fee_addon_params)
      end
      post_with_token(organization, "/api/v1/invoices", {invoice: create_invoice_params})
    end
  end

  def retry_invoice_payment(invoice_id, **kwargs)
    api_call(**kwargs) do
      post_with_token(organization, "/api/v1/invoices/#{invoice_id}/retry_payment")
    end
  end

  ### Payments

  def create_payment(customer, invoice, amount_cents, **kwargs)
    api_call(**kwargs) do
      post_with_token(organization, "/api/v1/payments", {
        payment: {
          invoice_id: invoice.id,
          amount_cents:,
          reference: SecureRandom.uuid.to_s
        }
      })
    end
  end

  ### Coupons

  def create_coupon(params, **kwargs)
    api_call(**kwargs) do
      post_with_token(organization, "/api/v1/coupons", {coupon: params})
    end
  end

  def apply_coupon(params, **kwargs)
    api_call(**kwargs) do
      post_with_token(organization, "/api/v1/applied_coupons", {applied_coupon: params})
    end
  end

  ### Taxes

  def create_tax(params, **kwargs)
    api_call(**kwargs) do
      post_with_token(organization, "/api/v1/taxes", {tax: params})
    end
  end

  # The mock always return a valid response,
  # To get an invalid response, simply use a invalid format (like YY123)
  def mock_vies_check!(vat_number)
    valvat = instance_double(Valvat)
    allow(Valvat).to receive(:new).with(vat_number).and_return(valvat)
    allow(valvat).to receive(:exists?).with(detail: true, raise_error: true).and_return({
      country_code: vat_number[0..1].upcase,
      vat_number: vat_number.upcase
    })
  end

  ### Wallets

  def create_wallet(params, as: :json, **kwargs)
    api_call(**kwargs) do
      post_with_token(organization, "/api/v1/wallets", {wallet: params})
    end
    parse_result(as, Wallet, :wallet)
  end

  def create_wallet_transaction(params, as: :json, **kwargs)
    api_call(**kwargs) do
      post_with_token(organization, "/api/v1/wallet_transactions", {wallet_transaction: params})
    end
    parse_result(as, WalletTransaction, :wallet_transactions)
  end

  def recalculate_wallet_balances
    Clock::RefreshLifetimeUsagesJob.perform_later
    Clock::RefreshWalletsOngoingBalanceJob.perform_later
    perform_all_enqueued_jobs
  end

  ### Events

  def ingest_event(subscription, billable_metric, amount)
    create_event({
      transaction_id: SecureRandom.uuid,
      code: billable_metric.code,
      external_subscription_id: subscription.external_id,
      properties: {billable_metric&.field_name => amount}
    })
    perform_usage_update
  end

  def create_event(params, **kwargs)
    params[:transaction_id] ||= SecureRandom.uuid

    response = api_call(**kwargs) do
      post_with_token(organization, "/api/v1/events", {event: params})
    end

    if organization.clickhouse_events_store?
      timestamp = params.key?(:timestamp) ? Time.zone.at(params[:timestamp]) : Time.iso8601(response.dig(:event, :timestamp))
      params = params.merge(timestamp:)
      create_clickhouse_event(params)
    end

    response
  end

  def estimate_event(params, **kwargs)
    api_call(**kwargs) do
      post_with_token(organization, "/api/v1/events/estimate_fees", {event: params})
    end
  end

  ### Credit notes

  def create_credit_note(params, **kwargs)
    api_call(**kwargs) do
      post_with_token(organization, "/api/v1/credit_notes", {credit_note: params})
    end
  end

  def estimate_credit_note(params, **kwargs)
    api_call(**kwargs) do
      post_with_token(organization, "/api/v1/credit_notes/estimate", {credit_note: params})
    end
  end

  ### Analytics

  def get_analytics(organization:, analytics_type:, months: 20, **kwargs)
    api_call(**kwargs) do
      get_with_token(organization, "/api/v1/analytics/#{analytics_type}", months:)
    end
  end

  ### Payment methods

  def setup_stripe_for(customer:)
    stripe_provider = create(:stripe_provider, organization:)
    stripe_customer = create(:stripe_customer, customer_id: customer.id, payment_provider: stripe_provider)
    create(:payment_method, payment_provider_customer: stripe_customer, is_default: true)
    customer.update!(payment_provider: "stripe", payment_provider_code: stripe_provider.code)
  end

  ### Fees

  def update_fee(fee_id, params, **kwargs)
    api_call(**kwargs) do
      put_with_token(organization, "/api/v1/fees/#{fee_id}", {fee: params})
    end
  end

  # Clock jobs

  def perform_billing
    clock_job do
      Clock::SubscriptionsBillerJob.perform_later
      Clock::FreeTrialSubscriptionsBillerJob.perform_later
    end
    perform_usage_update
  end

  def perform_invoices_refresh
    clock_job do
      Clock::RefreshDraftInvoicesJob.perform_later
    end
  end

  def perform_finalize_refresh
    clock_job do
      Clock::FinalizeInvoicesJob.perform_later
    end
  end

  def perform_usage_update
    clock_job do
      Clock::ComputeAllDailyUsagesJob.perform_later
      Clock::RefreshLifetimeUsagesJob.perform_later
      Clock::ProcessAllSubscriptionActivitiesJob.perform_later
    end
  end

  def perform_wallet_refresh
    clock_job do
      Clock::RefreshWalletsOngoingBalanceJob.perform_later
    end
  end

  def perform_overdue_balance_update
    clock_job do
      Clock::MarkInvoicesAsPaymentOverdueJob.perform_later
    end
  end

  def perform_dunning
    clock_job do
      Clock::ProcessDunningCampaignsJob.perform_later
    end
  end

  private

  def fetch_subscription(external_id)
    subscription = Subscription.find_by(external_id:)
    if subscription.nil?
      raise "Subscription not found for external_id: #{external_id}"
    end
    subscription
  end

  def fetch_billable_metric(code)
    billable_metric = BillableMetric.find_by(code:)
    if billable_metric.nil?
      raise "Billable metric not found for code: #{code}"
    end
    billable_metric
  end

  def fetch_charge(subscription, billable_metric)
    charge = subscription.plan.charges.find_by(billable_metric:)
    if charge.nil?
      raise "Charge not found for billable_metric: #{billable_metric.code}"
    end
    charge
  end

  def parse_result(as, model_class, key)
    case as
    when :json
      json.with_indifferent_access
    when :model
      array = key.to_s.pluralize == key.to_s
      if array
        model_class.where(id: json[key].pluck(:lago_id))
      else
        model_class.find(json[key][:lago_id])
      end
    else
      raise "Invalid as: #{as}"
    end
  end

  def create_clickhouse_event(params)
    subscription = fetch_subscription(params[:external_subscription_id])
    billable_metric = fetch_billable_metric(params[:code])
    charge = fetch_charge(subscription, billable_metric)

    params[:organization_id] = organization.id
    params[:value] ||= if billable_metric.count_agg?
      "1"
    else
      params.fetch(:properties, {}).with_indifferent_access.fetch(billable_metric.field_name).to_s
    end

    enriched_event = Clickhouse::EventsEnriched.create!(params)

    if charge.pay_in_advance?
      process_pay_in_advance_clickhouse_event(enriched_event)
    end
  end

  def process_pay_in_advance_clickhouse_event(enriched_event)
    common_event = Events::Common.new(
      id: nil,
      organization_id: enriched_event.organization_id,
      transaction_id: enriched_event.transaction_id,
      external_subscription_id: enriched_event.external_subscription_id,
      timestamp: enriched_event.timestamp,
      code: enriched_event.code,
      properties: enriched_event.properties,
      precise_total_amount_cents: enriched_event.precise_total_amount_cents
    )
    Events::PayInAdvanceJob.perform_later(common_event.as_json)
    perform_all_enqueued_jobs
  end
end
