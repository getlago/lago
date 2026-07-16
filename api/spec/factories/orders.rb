# frozen_string_literal: true

FactoryBot.define do
  factory :order do
    customer
    organization { customer&.organization || association(:organization) }
    order_form { association(:order_form, :signed, organization:, customer:) }

    trait :executed_in_lago do
      status { :executed }
      execution_mode { :execute_in_lago }
      executed_at { Time.current }
    end

    trait :executed_order_only do
      status { :executed }
      execution_mode { :order_only }
      executed_at { Time.current }
    end
  end
end
