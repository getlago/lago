# frozen_string_literal: true

require "rails_helper"

RSpec.describe Types::PaymentMethods::ReferenceInput do
  subject { described_class }

  it do
    expect(subject).to accept_argument(:payment_method_id).of_type("ID")
    expect(subject).to accept_argument(:payment_method_type).of_type("PaymentMethodTypeEnum")
  end
end
