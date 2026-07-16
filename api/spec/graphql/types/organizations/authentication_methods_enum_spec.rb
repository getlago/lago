# frozen_string_literal: true

require "rails_helper"

RSpec.describe Types::Organizations::AuthenticationMethodsEnum do
  it "enumerates the correct values" do
    expect(described_class.values.keys).to match_array(%w[email_password google_oauth okta])
  end
end
