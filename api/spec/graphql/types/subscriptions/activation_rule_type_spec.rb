# frozen_string_literal: true

require "rails_helper"

RSpec.describe Types::Subscriptions::ActivationRuleType do
  subject { described_class }

  it do
    expect(subject).to have_field(:id).of_type("ID!")
    expect(subject).to have_field(:expires_at).of_type("ISO8601DateTime")
    expect(subject).to have_field(:status).of_type("ActivationRuleStatusEnum!")
    expect(subject).to have_field(:timeout_hours).of_type("Int")
    expect(subject).to have_field(:type).of_type("ActivationRuleTypeEnum!")
    expect(subject).to have_field(:created_at).of_type("ISO8601DateTime!")
    expect(subject).to have_field(:updated_at).of_type("ISO8601DateTime!")
  end
end
