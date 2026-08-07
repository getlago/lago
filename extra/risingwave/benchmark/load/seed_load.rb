# frozen_string_literal: true

# Seeds the load-test population: N customers/subscriptions on the rwb plan
# (count + filtered + grouped charges from benchmark/seed.rb), billing
# periods for each, and wallets for the first WALLETS customers.
# Idempotent. Run: docker exec lago_api_dev bin/rails runner tmp/rw_benchmark/seed_load.rb

N = (ENV["LOAD_SUBS"] || 200).to_i
WALLETS = (ENV["LOAD_WALLETS"] || 20).to_i
ORG_ID = "791d70ac-ec99-41ca-b3ce-af19ee5171fa"

ActiveRecord::Base.logger = nil

org = Organization.find(ORG_ID)
billing_entity = org.billing_entities.first!
plan = Plan.find_by!(organization: org, code: "rwb_plan")

N.times do |i|
  customer = Customer.find_or_create_by!(organization: org, external_id: "rwbl_cust_#{i}") do |c|
    c.name = "RWB Load Customer #{i}"
    c.billing_entity = billing_entity
    c.currency = "EUR"
  end

  subscription = Subscription.find_or_create_by!(external_id: "rwbl_sub_#{i}") do |s|
    s.organization = org
    s.customer = customer
    s.plan = plan
    s.status = :active
    s.billing_time = :calendar
    s.subscription_at = Time.zone.parse("2026-06-01T00:00:00")
    s.started_at = Time.zone.parse("2026-06-01T00:00:00")
    s.billing_entity_id = customer.billing_entity_id
  end

  Subscriptions::BillingPeriods::UpsertService.call(subscription:)

  if i < WALLETS
    Wallet.find_or_create_by!(customer: customer, name: "RWB Load Wallet #{i}") do |w|
      w.organization_id = org.id
      w.currency = "EUR"
      w.rate_amount = 1
      w.status = :active
      w.credits_balance = 10_000
      w.balance_cents = 1_000_000
    end
  end

  print "." if (i % 20).zero?
end

puts "\nseeded: #{N} subscriptions, #{WALLETS} wallets"
