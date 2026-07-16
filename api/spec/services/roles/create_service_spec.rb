# frozen_string_literal: true

require "rails_helper"

RSpec.describe Roles::CreateService do
  include_context "with mocked security logger"

  describe "#call" do
    subject(:result) { described_class.call(organization:, code:, name:, description:, permissions:) }

    let(:organization) { create(:organization) }
    let(:code) { "custom_role" }
    let(:name) { "Custom Role" }
    let(:description) { "A custom role description" }
    let(:permissions) { %w[customers:view customers:create] }

    context "with premium license and custom_roles integration", :premium do
      before { organization.update!(premium_integrations: ["custom_roles"]) }

      it "creates a new role" do
        expect { result }.to change(Role, :count).by(1)
      end

      it "returns success" do
        expect(result).to be_success
      end

      it "returns the created role" do
        expect(result.role).to have_attributes(
          organization_id: organization.id,
          name:,
          description:,
          permissions:
        )
      end

      it_behaves_like "produces a security log", "role.created" do
        before { result }
      end

      context "with invalid params" do
        let(:name) { nil }

        it "does not create a role" do
          expect { result }.not_to change(Role, :count)
        end

        it "returns validation error" do
          expect(result).not_to be_success
          expect(result.error).to be_a(BaseService::ValidationFailure)
        end

        it_behaves_like "does not produce a security log" do
          before { result }
        end
      end

      context "with reserved code" do
        let(:code) { "admin" }

        it "does not create a role" do
          expect { result }.not_to change(Role, :count)
        end

        it "returns validation error" do
          expect(result).not_to be_success
          expect(result.error).to be_a(BaseService::ValidationFailure)
        end
      end
    end

    context "with premium license but without custom_roles integration", :premium do
      before { organization.update!(premium_integrations: []) }

      it "does not create a role" do
        expect { result }.not_to change(Role, :count)
      end

      it "returns forbidden error with code" do
        expect(result).not_to be_success
        expect(result.error).to be_a(BaseService::ForbiddenFailure)
        expect(result.error.code).to eq("premium_integration_missing")
      end

      it_behaves_like "does not produce a security log" do
        before { result }
      end
    end

    context "without premium license" do
      it "does not create a role" do
        expect { result }.not_to change(Role, :count)
      end

      it "returns forbidden error" do
        expect(result).not_to be_success
        expect(result.error).to be_a(BaseService::ForbiddenFailure)
      end

      it_behaves_like "does not produce a security log" do
        before { result }
      end
    end
  end
end
