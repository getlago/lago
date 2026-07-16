# frozen_string_literal: true

require "rails_helper"

RSpec.describe Types::Charges::PresentationGroupKeyOptionsInput do
  subject { described_class }

  it do
    expect(subject).to accept_argument(:display_in_invoice).of_type("Boolean")
  end
end
