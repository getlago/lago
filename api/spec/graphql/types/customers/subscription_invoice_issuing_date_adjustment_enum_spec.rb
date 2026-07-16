# frozen_string_literal: true

require "rails_helper"

RSpec.describe Types::Customers::SubscriptionInvoiceIssuingDateAdjustmentEnum do
  subject { described_class.values.keys }

  it { is_expected.to match_array(["keep_anchor", "align_with_finalization_date"]) }
end
