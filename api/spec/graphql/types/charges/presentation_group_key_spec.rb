# frozen_string_literal: true

require "rails_helper"

RSpec.describe Types::Charges::PresentationGroupKey do
  subject { described_class }

  it do
    expect(subject).to have_field(:value).of_type("String!")
    expect(subject).to have_field(:options).of_type("PresentationGroupKeyOptions")
  end
end
