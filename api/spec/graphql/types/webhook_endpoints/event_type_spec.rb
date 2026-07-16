# frozen_string_literal: true

require "rails_helper"

RSpec.describe Types::WebhookEndpoints::EventType do
  subject { described_class }

  it do
    expect(subject).to have_field(:name).of_type("String!")
    expect(subject).to have_field(:description).of_type("String!")
    expect(subject).to have_field(:category).of_type("EventCategoryEnum!")
    expect(subject).to have_field(:deprecated).of_type("Boolean!")
    expect(subject).to have_field(:key).of_type("EventTypeEnum!")
  end
end
