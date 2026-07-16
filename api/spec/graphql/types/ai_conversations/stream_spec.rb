# frozen_string_literal: true

require "rails_helper"

RSpec.describe Types::AiConversations::Stream do
  subject { described_class }

  it do
    expect(subject).to have_field(:chunk).of_type("String")
    expect(subject).to have_field(:done).of_type("Boolean!")
  end
end
