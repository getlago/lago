# frozen_string_literal: true

require "rails_helper"

RSpec.describe Types::BillingEntities::EmailSettingsEnum do
  subject { described_class.values.keys }

  it { is_expected.to match_array(["invoice_finalized", "credit_note_created", "payment_receipt_created"]) }
end
