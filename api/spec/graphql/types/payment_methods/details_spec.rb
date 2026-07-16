# frozen_string_literal: true

require "rails_helper"

RSpec.describe Types::PaymentMethods::Details do
  subject { described_class }

  it { is_expected.to have_field(:brand).of_type("String") }
  it { is_expected.to have_field(:expiration_month).of_type("String") }
  it { is_expected.to have_field(:expiration_year).of_type("String") }
  it { is_expected.to have_field(:last4).of_type("String") }
  it { is_expected.to have_field(:type).of_type("String") }
end
