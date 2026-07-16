# frozen_string_literal: true

FactoryBot.define do
  factory :data_export_part do
    data_export
    organization { data_export&.organization || association(:organization) }

    index { 0 }
    object_ids { [] }
  end
end
