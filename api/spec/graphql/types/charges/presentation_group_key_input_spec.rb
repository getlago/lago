# frozen_string_literal: true

require "rails_helper"

RSpec.describe Types::Charges::PresentationGroupKeyInput do
  subject { described_class }

  it do
    expect(subject).to accept_argument(:value).of_type("String!")
    expect(subject).to accept_argument(:options).of_type("PresentationGroupKeyOptionsInput")
  end
end
