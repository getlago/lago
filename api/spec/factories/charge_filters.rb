# frozen_string_literal: true

FactoryBot.define do
  factory :charge_filter do
    transient do
      charge { create(:standard_charge) }
    end

    organization { charge&.organization || association(:organization) }
    charge_id { charge.id }
    properties { charge.properties }
  end
end
