# frozen_string_literal: true

FactoryBot.define do
  trait :deleted do
    deleted_at { Time.current }
  end
end
