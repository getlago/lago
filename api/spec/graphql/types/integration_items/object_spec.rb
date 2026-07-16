# frozen_string_literal: true

require "rails_helper"

RSpec.describe Types::IntegrationItems::Object do
  subject { described_class }

  it do
    expect(subject).to have_field(:external_account_code).of_type("String")
    expect(subject).to have_field(:external_id).of_type("String!")
    expect(subject).to have_field(:id).of_type("ID!")
    expect(subject).to have_field(:integration_id).of_type("ID!")
    expect(subject).to have_field(:item_type).of_type("IntegrationItemTypeEnum!")
    expect(subject).to have_field(:external_name).of_type("String")
  end
end
