# frozen_string_literal: true

require "rails_helper"

RSpec.describe Types::Integrations::Avalara::CreateInput do
  subject { described_class }

  it do
    expect(subject).to accept_argument(:code).of_type("String!")
    expect(subject).to accept_argument(:name).of_type("String!")
    expect(subject).to accept_argument(:company_code).of_type("String!")
    expect(subject).to accept_argument(:connection_id).of_type("String!")
    expect(subject).to accept_argument(:account_id).of_type("String!")
    expect(subject).to accept_argument(:license_key).of_type("String!")
  end
end
