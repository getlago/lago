# frozen_string_literal: true

# NOTE: If hooli is not found, run 01_base.rb first
@organization = Organization.find_by!(name: "Hooli")
@customer = Customer.find_by!(external_id: "cust_john-doe")
@sub = Subscription.find_by!(external_id: "sub_john-doe-main")
sum_bm = BillableMetric.find_by!(organization: @organization, code: "sum_bm")
count_bm = BillableMetric.find_by!(organization: @organization, code: "count_bm")

def create_event(code:, time:)
  Event.create!(
    external_customer_id: @customer.external_id,
    external_subscription_id: @sub.external_id,
    organization_id: @organization.id,
    transaction_id: "tr_#{SecureRandom.hex}",
    timestamp: time - rand(0..12).seconds,
    created_at: time,
    code: code,
    properties: {
      custom_field: 10
    },
    metadata: {
      user_agent: "Lago Python v0.1.5",
      ip_address: Faker::Internet.ip_v4_address
    }
  )
end

# NOTE: Assigns valid events
6.times do |offset|
  5.times do
    create_event(code: sum_bm.code, time: (offset.month + rand(1..20).days).ago)
  end

  2.times do
    create_event(code: count_bm.code, time: (offset.month + rand(1..20).days).ago)
  end
end

# NOTE: Assigns events missing custom property
5.times do
  event = create_event(code: sum_bm.code, time: rand(1..20).days.ago)
  event.properties = {}
  event.save!
end

# NOTE: Assigns events with invalid code
5.times do
  create_event(code: "foo", time: rand(1..20).days.ago)
end
