# frozen_string_literal: true

require "faker"
require "factory_bot_rails"

# Enable premium features for seeding
License.instance_variable_set(:@premium, true)

# Ensure predefined roles exist (normally created by migration)
Role.find_or_create_by!(code: "admin", organization_id: nil) do |role|
  role.admin = true
  role.name = "Admin"
  role.description = "Administrator having all permissions"
end

Role.find_or_create_by!(code: "finance", organization_id: nil) do |role|
  role.name = "Finance"
  role.description = "Finance role with permissions to manage financial data"
end

Role.find_or_create_by!(code: "manager", organization_id: nil) do |role|
  role.name = "Manager"
  role.description = "The predefined manager role"
end

# NOTE: create users and an organization
user = User.create_with(password: "ILoveLago")
  .find_or_create_by(email: "gavin@hooli.com")

dinesh = User.create_with(password: "ILoveLago")
  .find_or_create_by(email: "dinesh@hooli.com")

organizations_data = [
  {
    name: "Hooli",
    id: "11111111-2222-3333-4444-555555555555",
    api_key: "lago_key-hooli-1234567890",
    clickhouse_events_store: false
  }
]
if ENV["LAGO_CLICKHOUSE_ENABLED"] == "true"
  organizations_data << {
    name: "Hooli Clickhouse",
    id: "22222222-3333-4444-5555-666666666666",
    api_key: "lago_key-hooli-clickhouse-1234567890",
    clickhouse_events_store: true
  }
end

organizations_data.each do |org_data|
  name, id, api_key, clickhouse_events_store = org_data.values_at(:name, :id, :api_key, :clickhouse_events_store)
  organization = Organization.find_by(name:)
  if organization.nil?
    organization = Organization.create!(id:, name:, clickhouse_events_store:)
  end
  organization.update!({
    premium_integrations: Organization::PREMIUM_INTEGRATIONS,
    invoice_footer: "Hooli is a fictional company."
  })
  billing_entity = BillingEntity.find_or_create_by!(organization:, name: "Hooli", code: "hooli")
  billing_entity.update!(
    email: "gavin@hooli.com",
    email_settings: BillingEntity::EMAIL_SETTINGS
  )
  membership = Membership.find_or_create_by!(user:, organization:)

  # Ensure the membership has an admin role in the new roles system
  admin_role = Role.find_by!(admin: true)
  MembershipRole.find_or_create_by!(membership:, organization:, role: admin_role)

  # Second user with finance role
  dinesh_membership = Membership.find_or_create_by!(user: dinesh, organization:)
  finance_role = Role.find_by!(code: "finance")
  MembershipRole.find_or_create_by!(membership: dinesh_membership, organization:, role: finance_role)

  # Custom role combining finance and manager permissions
  accountant_permissions = Permission::DATA
    .select { |_, roles| roles.include?("finance") || roles.include?("manager") }.keys
  Role.find_or_create_by!(code: "accountant", organization:) do |role|
    role.name = "Accountant"
    role.description = "Custom role combining finance and manager permissions"
    role.permissions = accountant_permissions
  end

  # Anrok integration
  unless Integrations::AnrokIntegration.exists?(organization:, code: "anrok")
    Integrations::AnrokIntegration.create!(
      organization:,
      code: "anrok",
      name: "Anrok Integration",
      secrets: {connection_id: SecureRandom.uuid, api_key: SecureRandom.uuid}.to_json
    )
  end

  if Rails.env.development?
    # In development, we create a webhook endpoint to the local webhook-tester service.
    WebhookEndpoint.find_or_create_by!(organization:, webhook_url: "http://webhook/#{organization.id}")
  end
  organization.api_keys.destroy_all
  organization.api_keys.create!(name: "Expired Key", expires_at: 1.day.ago, last_used_at: 36.hours.ago, permissions: {"customer" => ["read", "write"]})
  k = organization.api_keys.create!(name: "Hooli Key", permissions: ApiKey.default_permissions)
  k.update_columns(value: api_key) # rubocop:disable Rails/SkipsModelValidations

  # == BillableMetrics

  sum_bm = BillableMetric.find_by(organization:, code: "sum_bm") || BillableMetrics::CreateService.call!(
    organization_id: organization.id,
    aggregation_type: "sum_agg",
    name: "Sum BM",
    code: "sum_bm",
    field_name: "custom_field"
  ).billable_metric

  count_bm = BillableMetric.find_by(organization:, code: "count_bm") || BillableMetrics::CreateService.call!(
    organization_id: organization.id,
    aggregation_type: "count_agg",
    name: "Count BM",
    code: "count_bm"
  ).billable_metric

  # == Taxes

  unless Tax.exists?(organization:, code: "lago_eu_fr_standard")
    Taxes::CreateService.call!(
      organization:,
      params: {
        name: "FR Standard",
        code: "lago_eu_fr_standard",
        description: "FR Standard",
        rate: 20
      }
    )
  end

  # == Addons

  unless AddOn.exists?(organization:, code: "setup_fee")
    AddOns::CreateService.call!(
      organization_id: organization.id,
      name: "Setup Fee",
      code: "setup_fee",
      description: "Fee for setting up the subscription",
      amount_cents: 100_00,
      amount_currency: "EUR",
      tax_codes: ["lago_eu_fr_standard"]
    )
  end

  unless AddOn.exists?(organization:, code: "setup_fee")
    AddOns::CreateService.call!(
      organization_id: organization.id,
      name: "Hour of Premium Support",
      code: "support_hour",
      description: "One hour of support from our experts",
      amount_cents: 84_99,
      amount_currency: "EUR",
      tax_codes: ["lago_eu_fr_standard"]
    )
  end

  # == Coupons

  unless Coupon.exists?(organization:, code: "20_percent_off")
    Coupons::CreateService.call!(
      organization_id: organization.id,
      name: "20% off",
      code: "20_percent_off",
      coupon_type: "percentage",
      percentage_rate: 20,
      frequency: "forever",
      expiration: "no_expiration"
    )
  end

  unless Coupon.exists?(organization:, code: "10_euro_off")
    Coupons::CreateService.call!(
      organization_id: organization.id,
      name: "10€ off",
      code: "10_euro_off",
      coupon_type: "fixed_amount",
      amount_cents: 1000,
      amount_currency: "EUR",
      frequency: "forever",
      expiration: "no_expiration"
    )
  end

  # == Plans

  unless Plan.exists?(organization:, code: "standard_plan")
    standard_plan_params = {
      organization_id: organization.id,
      name: "Standard Plan",
      code: "standard_plan",
      interval: "monthly",
      pay_in_advance: true,
      amount_cents: 19_99,
      amount_currency: "EUR",
      tax_codes: ["lago_eu_fr_standard"],
      charges: [
        {
          billable_metric_id: sum_bm.id,
          charge_model: "standard",
          amount_currency: "EUR",
          pay_in_advance: false,
          properties: {
            amount: 100.to_s
          }
        },
        {
          billable_metric_id: count_bm.id,
          charge_model: "standard",
          amount_currency: "EUR",
          pay_in_advance: false,
          properties: {
            amount: 499.to_s
          }
        }
      ]
    }
    Plans::CreateService.call!(standard_plan_params)
  end

  unless Plan.exists?(organization:, code: "premium_plan")
    premium_plan_params = {
      organization_id: organization.id,
      name: "Premium Plan",
      code: "premium_plan",
      interval: "monthly",
      pay_in_advance: true,
      amount_cents: 100_00,
      amount_currency: "EUR",
      tax_codes: ["lago_eu_fr_standard"],
      charges: [
        {
          billable_metric_id: sum_bm.id,
          charge_model: "standard",
          amount_currency: "EUR",
          pay_in_advance: false,
          properties: {
            amount: 30.to_s
          }
        },
        {
          billable_metric_id: count_bm.id,
          charge_model: "standard",
          amount_currency: "EUR",
          pay_in_advance: false,
          properties: {
            amount: 399.to_s
          }
        }
      ]
    }
    Plans::CreateService.call!(premium_plan_params)
  end

  unless PricingUnit.exists?(organization:, code: "xyz")
    PricingUnits::CreateService.call!(
      organization:,
      name: "xyz",
      code: "xyz",
      short_name: "XYZ"
    )
  end
end
