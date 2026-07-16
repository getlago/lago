# frozen_string_literal: true

require "rails_helper"

RSpec.describe Types::Entitlement::PrivilegeConfigObject do
  subject { described_class }

  it do
    expect(subject).to have_field(:select_options).of_type("[String!]")
  end
end
