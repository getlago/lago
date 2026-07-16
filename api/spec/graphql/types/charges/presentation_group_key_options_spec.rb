# frozen_string_literal: true

require "rails_helper"

RSpec.describe Types::Charges::PresentationGroupKeyOptions do
  subject { described_class }

  it do
    expect(subject).to have_field(:display_in_invoice).of_type("Boolean")
  end
end
