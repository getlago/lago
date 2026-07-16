# frozen_string_literal: true

require "rails_helper"

RSpec.describe Types::BillingEntities::SubscriptionInvoiceIssuingDateAnchorEnum do
  subject { described_class.values.keys }

  it { is_expected.to match_array(["current_period_end", "next_period_start"]) }
end
