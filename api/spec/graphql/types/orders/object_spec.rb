# frozen_string_literal: true

require "rails_helper"

RSpec.describe Types::Orders::Object do
  subject { described_class }

  it do
    expect(subject).to have_field(:execution_mode).of_type("OrderExecutionModeEnum")
    expect(subject).to have_field(:id).of_type("ID!")
    expect(subject).to have_field(:number).of_type("String!")
    expect(subject).to have_field(:order_type).of_type("OrderTypeEnum!")
    expect(subject).to have_field(:status).of_type("OrderStatusEnum!")

    expect(subject).to have_field(:billing_snapshot).of_type("JSON!")
    expect(subject).to have_field(:currency).of_type("String")
    expect(subject).to have_field(:execute_at).of_type("ISO8601DateTime")
    expect(subject).to have_field(:executed_at).of_type("ISO8601DateTime")

    expect(subject).to have_field(:customer).of_type("Customer!")
    expect(subject).to have_field(:order_form).of_type("OrderForm!")
    expect(subject).to have_field(:organization).of_type("Organization!")

    expect(subject).to have_field(:created_at).of_type("ISO8601DateTime!")
    expect(subject).to have_field(:updated_at).of_type("ISO8601DateTime!")
  end
end
