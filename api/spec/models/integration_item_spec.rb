# frozen_string_literal: true

require "rails_helper"

RSpec.describe IntegrationItem do
  subject(:integration_item) { build(:integration_item) }

  it_behaves_like "paper_trail traceable"

  it { is_expected.to belong_to(:integration) }
  it { is_expected.to belong_to(:organization) }
  it { is_expected.to validate_presence_of(:external_id) }
  it { is_expected.to define_enum_for(:item_type).with_values(%i[standard tax account]) }

  it "validates uniqueness of external id" do
    expect(integration_item).to validate_uniqueness_of(:external_id).scoped_to([:integration_id, :item_type])
  end
end
