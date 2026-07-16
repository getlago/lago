# frozen_string_literal: true

require "rails_helper"

RSpec.describe ApiKeyMailer do
  describe "#rotated" do
    let(:mail) { described_class.with(api_key:).rotated }
    let(:api_key) { create(:api_key) }
    let(:organization) { api_key.organization }

    before { create(:membership, organization:, roles: [:admin]) }

    describe "subject" do
      subject { mail.subject }

      it { is_expected.to eq "Your Lago API key has been rolled" }
    end

    describe "recipients" do
      subject { mail.bcc }

      before { create(:membership, organization:, roles: [:manager]) }

      specify do
        expect(subject)
          .to be_present
          .and eq organization.admins.pluck(:email)
      end
    end

    describe "body" do
      subject { mail.body.to_s }

      it "includes organization's name" do
        expect(subject).to include CGI.escapeHTML(organization.name)
      end
    end
  end

  describe "#created" do
    let(:mail) { described_class.with(api_key:).created }
    let(:api_key) { create(:api_key) }
    let(:organization) { api_key.organization }

    before { create(:membership, organization:, roles: [:admin]) }

    describe "subject" do
      subject { mail.subject }

      it { is_expected.to eq "A new Lago API key has been created" }
    end

    describe "recipients" do
      subject { mail.bcc }

      before { create(:membership, organization:, roles: [:manager]) }

      specify do
        expect(subject)
          .to be_present
          .and eq organization.admins.pluck(:email)
      end
    end

    describe "body" do
      subject { mail.body.to_s }

      it "includes organization's name" do
        expect(subject).to include CGI.escapeHTML(organization.name)
      end
    end
  end

  describe "#destroyed" do
    let(:mail) { described_class.with(api_key:).destroyed }
    let(:api_key) { create(:api_key) }
    let(:organization) { api_key.organization }

    before { create(:membership, organization:, roles: [:admin]) }

    describe "subject" do
      subject { mail.subject }

      it { is_expected.to eq "A Lago API key has been deleted" }
    end

    describe "recipients" do
      subject { mail.bcc }

      before { create(:membership, organization:, roles: [:manager]) }

      specify do
        expect(subject)
          .to be_present
          .and eq organization.admins.pluck(:email)
      end
    end

    describe "body" do
      subject { mail.body.to_s }

      it "includes organization's name" do
        expect(subject).to include CGI.escapeHTML(organization.name)
      end
    end
  end
end
