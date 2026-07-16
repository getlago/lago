# frozen_string_literal: true

FactoryBot.define do
  sequence(:future_date) { rand(1..(10**7)).seconds.from_now }
  sequence(:past_date) { rand(1..(10**7)).seconds.ago }
end
