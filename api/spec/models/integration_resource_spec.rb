# frozen_string_literal: true

require "rails_helper"

RSpec.describe IntegrationResource do
  subject(:integration_resource) { build(:integration_resource) }

  let(:resource_types) do
    %i[invoice sales_order_deprecated payment credit_note subscription]
  end

  it_behaves_like "paper_trail traceable"

  it { is_expected.to belong_to(:syncable) }
  it { is_expected.to belong_to(:integration) }
  it { is_expected.to belong_to(:organization) }

  it { is_expected.to define_enum_for(:resource_type).with_values(resource_types) }
end
