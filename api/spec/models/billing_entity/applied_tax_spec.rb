# frozen_string_literal: true

require "rails_helper"

RSpec.describe BillingEntity::AppliedTax do
  subject(:billing_entity_applied_tax) { create(:billing_entity_applied_tax) }

  it { is_expected.to belong_to(:billing_entity) }
  it { is_expected.to belong_to(:tax) }
  it { is_expected.to belong_to(:organization) }
end
