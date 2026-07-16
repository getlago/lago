# frozen_string_literal: true

require "rails_helper"

RSpec.describe Types::Subscriptions::ActivationRuleInput do
  subject { described_class }

  it do
    expect(subject).to accept_argument(:id).of_type("ID")
    expect(subject).to accept_argument(:timeout_hours).of_type("Int")
    expect(subject).to accept_argument(:type).of_type("ActivationRuleTypeEnum!")
  end
end
