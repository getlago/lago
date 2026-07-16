# frozen_string_literal: true

require "rails_helper"

RSpec.describe OrganizationMailer do
  subject(:organization_mailer) do
    described_class.with(organization:, user: admin0, additions:, deletions:).authentication_methods_updated
  end

  let(:organization) { create(:organization) }
  let(:additions) { ["okta"] }
  let(:deletions) { ["google_oauth"] }

  let(:admin0) { create(:membership, organization:, roles: [:admin], user: create(:user)).user }
  let(:admin1) { create(:membership, organization:, roles: [:admin], user: create(:user)).user }
  let(:admin2) { create(:membership, organization:, roles: [:admin], user: create(:user)).user }

  before do
    admin0
    admin1
    admin2
  end

  describe "#authentication_methods_updated" do
    specify do
      expect(subject.subject).to eq("Login method updated in your Lago workspace")
      expect(subject.bcc).to contain_exactly(admin0.email, admin1.email, admin2.email)
      expect(subject.from).to eq(["noreply@getlago.com"])
      expect(subject.reply_to).to eq(["noreply@getlago.com"])

      email_body = subject.message.body
      expect(email_body).to include(admin0.email)
      expect(email_body).to include("Enabled Okta")
      expect(email_body).to include("Disabled Google Oauth")
    end

    context "without changes" do
      let(:additions) { [] }
      let(:deletions) { [] }

      it "returns a message with nil values" do
        expect(subject.message).to be_a(ActionMailer::Base::NullMail)
      end
    end
  end
end
