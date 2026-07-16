# frozen_string_literal: true

require "rails_helper"

RSpec.describe Types::BillingEntities::DocumentNumberingEnum do
  subject { described_class.values.keys }

  it { is_expected.to match_array(["per_customer", "per_billing_entity"]) }
end
