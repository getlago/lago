# frozen_string_literal: true

require "rails_helper"

RSpec.describe Organizations::AuthenticationMethods do
  describe "authentication_methods" do
    let(:organization) { create(:organization) }

    before do
      organization
    end

    it "creates with default values" do
      expect(organization.authentication_methods.count).to eq(Organization::FREE_AUTHENTICATION_METHODS.count)
      expect(organization.authentication_methods).to eq(Organization::FREE_AUTHENTICATION_METHODS)
    end

    Organization::FREE_AUTHENTICATION_METHODS.each do |auth|
      context "when FREE AUTHENTICATION METHOD #{auth}" do
        it "is enabled by default" do
          expect(organization.authentication_methods).to include(auth)
        end

        it "can be disabled" do
          expect(organization.send(:"disable_#{auth}_authentication!")).to be_truthy
          expect(organization.send(:"#{auth}_authentication_enabled?")).to be_falsey
        end

        it "can be enabled" do
          expect(organization.send(:"enable_#{auth}_authentication!")).to be_truthy
          expect(organization.send(:"#{auth}_authentication_enabled?")).to be_truthy
        end
      end
    end

    Organization::PREMIUM_AUTHENTICATION_METHODS.each do |auth|
      context "when PREMIUM AUTHENTICATION METHOD #{auth}" do
        it "is not enabled by default" do
          expect(organization.authentication_methods).not_to include(auth)
        end

        context "with free organization" do
          it "cant be enabled" do
            expect(organization.send(:"enable_#{auth}_authentication!")).to be_falsey
            expect(organization.send(:"#{auth}_authentication_enabled?")).to be_falsey
          end
        end

        context "with premium organization", :premium do
          before do
            organization.premium_integrations << auth
          end

          it "can be enabled" do
            expect(organization.send(:"enable_#{auth}_authentication!")).to be_truthy
            expect(organization.send(:"#{auth}_authentication_enabled?")).to be_truthy
          end

          it "can be disabled" do
            organization.send(:"enable_#{auth}_authentication!")
            expect(organization.send(:"disable_#{auth}_authentication!")).to be_truthy
            expect(organization.send(:"#{auth}_authentication_enabled?")).to be_falsey
          end
        end
      end
    end

    context "when disabling authentication methods" do
      it "cant disable all" do
        expect do
          organization.authentication_methods.dup.each do |auth|
            organization.send(:"disable_#{auth}_authentication!")
          end
        end.to raise_error(ActiveRecord::RecordInvalid)
      end
    end

    context "when invalid auth" do
      it "cant save" do
        expect do
          organization.authentication_methods = ["strange"]
          organization.save!
        end.to raise_error(ActiveRecord::RecordInvalid)
      end
    end
  end
end
