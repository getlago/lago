# frozen_string_literal: true

FactoryBot.define do
  factory :credit_note do
    customer
    invoice
    organization { customer&.organization || invoice&.organization || association(:organization) }

    issuing_date { Time.zone.today }

    reason { "duplicated_charge" }
    total_amount_cents { 120 }
    total_amount_currency { "EUR" }
    taxes_amount_cents { 20 }

    credit_status { "available" }
    credit_amount_cents { 120 }
    credit_amount_currency { "EUR" }
    balance_amount_cents { 120 }
    balance_amount_currency { "EUR" }

    trait :with_file do
      after(:build) do |credit_note|
        credit_note.file.attach(
          io: File.open(Rails.root.join("spec/fixtures/blank.pdf")),
          filename: "blank.pdf",
          content_type: "application/pdf"
        )
      end
    end

    trait :draft do
      status { :draft }
    end

    trait :with_tax_error do
      after :create do |i|
        create(:error_detail, owner: i, error_code: "tax_error")
      end
    end

    trait :with_items do
      items { create_pair(:credit_note_item) }
    end

    trait :with_metadata do
      after(:create) do |credit_note|
        credit_note.create_metadata!(
          organization_id: credit_note.organization_id,
          value: {"key" => "value"}
        )
      end
    end
  end
end
