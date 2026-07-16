# frozen_string_literal: true

# NOTE: If hooli is not found, run 01_base.rb first
organization = Organization.find_by!(name: "Hooli")
billing_entity = organization.default_billing_entity
plan = Plan.find_by!(code: "standard_plan")

# Create and customers with subscriptions to add "noise" to the system
5.times do |i|
  customer = Customer.create_with(
    name: Faker::TvShows::SiliconValley.character,
    country: Faker::Address.country_code,
    address_line1: Faker::Address.street_address,
    address_line2: Faker::Address.secondary_address,
    zipcode: Faker::Address.zip_code,
    email: Faker::Internet.email,
    city: Faker::Address.city,
    legal_name: Faker::Company.name,
    legal_number: Faker::Company.duns_number,
    currency: "EUR"
  ).find_or_create_by!(
    organization:,
    billing_entity:,
    external_id: "cust_#{i + 1}"
  )

  subscription_at = 6.months.ago

  Subscription.create_with(
    organization:,
    started_at: subscription_at,
    subscription_at:,
    status: :active,
    billing_time: :calendar,
    created_at: subscription_at
  ).find_or_create_by!(
    customer:,
    external_id: "sub_#{i + 1}",
    plan:
  )
end
