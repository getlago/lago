# frozen_string_literal: true

require "rails_helper"

RSpec.describe Invites::CreateService do
  subject(:create_service) { described_class.new(create_args) }

  include_context "with mocked security logger"

  let(:admin_role) { create(:role, :admin) }
  let(:membership) { create(:membership) }
  let(:organization) { membership.organization }

  before { create(:membership_role, membership:, role: admin_role) }

  describe "#call" do
    let(:create_args) do
      {
        email: Faker::Internet.email,
        current_organization: organization,
        user: membership.user,
        roles: %w[admin]
      }
    end

    it "creates an invite" do
      expect { create_service.call }
        .to change(Invite, :count).by(1)
    end

    it_behaves_like "produces a security log", "user.invited" do
      before { create_service.call }
    end

    context "when non-admin invites with admin role" do
      let(:non_admin_membership) { create(:membership, organization:) }
      let(:create_args) do
        {
          email: Faker::Internet.email,
          current_organization: organization,
          user: non_admin_membership.user,
          roles: %w[admin]
        }
      end

      it "returns an error" do
        result = create_service.call

        expect(result).not_to be_success
        expect(result.error).to be_a(BaseService::ForbiddenFailure)
        expect(result.error.code).to eq("cannot_grant_admin")
      end

      it_behaves_like "does not produce a security log" do
        before { create_service.call }
      end
    end

    context "with validation error" do
      let(:create_args) do
        {
          current_organization: organization,
          user: membership.user,
          roles: %w[admin]
        }
      end

      it "returns an error" do
        result = create_service.call

        expect(result).not_to be_success
        expect(result.error).to be_a(BaseService::ValidationFailure)
        expect(result.error.messages[:email]).to eq(%w[invalid_email_format])
      end

      it_behaves_like "does not produce a security log" do
        before { create_service.call }
      end
    end

    context "with missing roles" do
      let(:create_args) do
        {
          email: Faker::Internet.email,
          current_organization: organization,
          user: membership.user
        }
      end

      it "returns an error" do
        result = create_service.call

        expect(result).not_to be_success
        expect(result.error).to be_a(BaseService::ValidationFailure)
        expect(result.error.messages[:roles]).to eq(%w[invalid_role])
      end

      it_behaves_like "does not produce a security log" do
        before { create_service.call }
      end
    end

    context "with invalid roles" do
      let(:create_args) do
        {
          email: Faker::Internet.email,
          current_organization: organization,
          user: membership.user,
          roles: %w[nonexistent_role]
        }
      end

      it "returns an error" do
        result = create_service.call

        expect(result).not_to be_success
        expect(result.error).to be_a(BaseService::ValidationFailure)
        expect(result.error.messages[:roles]).to eq(%w[invalid_role])
      end

      it_behaves_like "does not produce a security log" do
        before { create_service.call }
      end
    end

    context "with already existing invite" do
      it "returns an error" do
        create(:invite, organization: create_args[:current_organization], email: create_args[:email])
        result = create_service.call

        expect(result).not_to be_success
        expect(result.error).to be_a(BaseService::ValidationFailure)
        expect(result.error.messages.keys).to eq([:invite])
      end

      it_behaves_like "does not produce a security log" do
        before do
          create(:invite, organization: create_args[:current_organization], email: create_args[:email])
          create_service.call
        end
      end
    end

    context "with already existing member" do
      let(:user) { create(:user, email: create_args[:email]) }

      it "returns an error" do
        create(:membership, organization:, user:)

        result = create_service.call

        expect(result).not_to be_success
        expect(result.error).to be_a(BaseService::ValidationFailure)
        expect(result.error.messages.keys).to eq([:email])
      end

      it_behaves_like "does not produce a security log" do
        before do
          create(:membership, organization:, user:)
          create_service.call
        end
      end
    end
  end
end
