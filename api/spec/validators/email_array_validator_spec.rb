# frozen_string_literal: true

require "rails_helper"

RSpec.describe EmailArrayValidator do
  subject(:validator) { described_class.new(attributes: [:bcc_emails]) }

  let(:model) { DunningCampaign.new(bcc_emails:) }

  [
    "test@example.com",
    "test+1@example.com",
    "test.1@example.com",
    "test-1@example.com",
    "test_1@example.com",
    "test123@example.com",
    "!#$%&'*+/=?^_`{|}~-test123!#$%&'*+/=?^_`{|}~-@example.com",
    "test@sub.example.com",
    "test@dash-in-domain.com",
    "with.dot@example.com",
    "with.dot+plus-and-dash@example.com",
    "x@example.com",
    "example@s.example",
    "1234567890@example.com",
    "_______@example.com",
    ["first.user@example.com", "second+user@example.com", "third_user@example.com"]
  ].each do |email|
    context "when the email is #{email}" do
      let(:bcc_emails) { Array(email) }

      it "is valid" do
        validator.validate(model)
        expect(model.errors.full_messages).to be_empty
      end
    end
  end

  [
    # Unicode
    "with.uniçode@example.com",

    # Missing @
    "userdomain.com",
    "user.domain.com",

    # Multiple @
    "user@@domain.com",
    "user@domain@com",

    # Missing domain
    "user@",
    "user@.",
    "user@.com",

    # Invalid domain format
    "user@domain..com",
    "user@.domain.com",
    "user@domain.com.",
    "user@-domain.com",

    # Spaces
    "user name@domain.com",
    "user@domain name.com",
    "user @domain.com",

    # Invalid characters
    "user<name@domain.com",
    "user>name@domain.com",
    "user(name@domain.com",
    "user)name@domain.com",

    # Consecutive dots
    "user..name@domain.com",
    "user@domain..com",

    # Dots at start/end
    ".user@domain.com",
    "user.@domain.com",
    "user@.domain.com",
    "user@domain.com.",

    # Invalid TLD
    # TODO: Handle these cases ?
    #
    # "user@domain.c",
    # "user@domain.123",

    # Invalid IP
    "user@[192.168.1.1",
    "user@192.168.1.1]",
    "user@[256.256.256.256]",

    # Invalid quoted strings
    "\"user@domain.com",
    "user\"@domain.com",

    # Edge cases
    "user@domain..com",
    "user@domain...com",
    "user....name@domain.com",
    "user@domain.com.",
    "user@domain.com.."
  ].each do |email|
    context "when the email is #{email}" do
      let(:bcc_emails) { [email] }

      it "is invalid" do
        validator.validate(model)
        expect(model.errors.to_hash).to eq(bcc_emails: ["invalid_email_format[0,#{email}]"])
      end
    end
  end
end
