# frozen_string_literal: true

FactoryBot.define do
  factory :invoice do
    customer
    # TODO: change building invoices from billing_entity by default
    organization { customer&.organization || association(:organization) }

    issuing_date { Time.zone.now - 1.day }
    expected_finalization_date { Time.zone.now - 1.day }
    payment_due_date { issuing_date }
    payment_status { "pending" }
    currency { "EUR" }
    # in case the organization was only build and not saved, it won't have a default_billing_entity, so we need
    # to build it as well
    billing_entity { organization&.default_billing_entity || association(:billing_entity) }

    organization_sequential_id { rand(1_000_000) }

    trait :draft do
      status { :draft }
    end

    trait :open do
      status { :open }
    end

    trait :credit do
      invoice_type { :credit }
    end

    trait :dispute_lost do
      payment_dispute_lost_at { DateTime.current - 1.day }
    end

    trait :with_tax_error do
      after :create do |i|
        create(:error_detail, owner: i, error_code: "tax_error")
      end
    end

    trait :with_tax_voiding_error do
      after :create do |i|
        create(:error_detail, owner: i, error_code: "tax_voiding_error")
      end
    end

    trait :failed do
      status { :failed }
    end

    trait :pending do
      status { :pending }
    end

    trait :voided do
      status { :voided }
    end

    trait :with_subscriptions do
      transient do
        subscriptions { [create(:subscription, organization:)] }
      end

      after :create do |invoice, evaluator|
        evaluator.subscriptions.each do |subscription|
          create(:invoice_subscription, :boundaries, invoice:, subscription:)
        end
      end
    end

    trait :subscription do
      invoice_type { :subscription }
      with_subscriptions
    end

    trait :self_billed do
      self_billed { true }
    end

    trait :invisible do
      status { Invoice::INVISIBLE_STATUS.keys.sample }
    end

    trait :progressive_billing_invoice do
      invoice_type { :progressive_billing }
      with_subscriptions
      after :create do |invoice|
        create(:applied_usage_threshold, invoice:, organization: invoice.organization)
      end
    end
  end
end
