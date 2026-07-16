# frozen_string_literal: true

require "rails_helper"

RSpec.describe ApiKeys::DestroyService do
  include_context "with mocked security logger"

  describe "#call" do
    subject(:service_result) { described_class.call(api_key, **kwargs) }

    let(:kwargs) { {} }

    context "when API key is missing" do
      let(:api_key) { nil }

      it "returns an error" do
        expect(service_result).not_to be_success
        expect(service_result.error).to be_a(BaseService::NotFoundFailure)
        expect(service_result.error.error_code).to eq("api_key_not_found")
      end

      it "does not send an API key destroyed email" do
        expect { service_result }.not_to have_enqueued_mail(ApiKeyMailer, :destroyed)
      end

      it_behaves_like "does not produce a security log" do
        before { service_result }
      end
    end

    context "when API key is present" do
      let!(:api_key) { create(:api_key) }

      context "when organization has another non-expiring key" do
        before do
          create(:api_key, organization: api_key.organization)
          freeze_time
        end

        it "expires the API key with current time" do
          expect { subject }.to change(api_key, :expires_at).to(Time.current)
        end

        it "sends an API key destroyed email" do
          expect { service_result }
            .to have_enqueued_mail(ApiKeyMailer, :destroyed).with hash_including(params: {api_key:})
        end

        it_behaves_like "produces a security log", "api_key.deleted" do
          before { service_result }
        end
      end

      context "when organization has no another non-expiring key" do
        before { create(:api_key, :expired, organization: api_key.organization) }

        it "returns an error" do
          expect(service_result).not_to be_success
          expect(service_result.error).to be_a(BaseService::ValidationFailure)
          expect(service_result.error.messages.values.flatten).to include("last_non_expiring_api_key")
        end

        it "does not expire the key" do
          expect { subject }.not_to change(api_key, :expires_at).from(nil)
        end

        it "does not send an API key destroyed email" do
          expect { service_result }.not_to have_enqueued_mail(ApiKeyMailer, :destroyed)
        end

        it_behaves_like "does not produce a security log" do
          before { service_result }
        end

        context "with force: true" do
          let(:kwargs) { {force: true} }

          before { freeze_time }

          it "expires the key" do
            expect { subject }.to change(api_key, :expires_at).to(Time.current)
          end

          it "does not send an API key destroyed email" do
            expect { service_result }.not_to have_enqueued_mail(ApiKeyMailer, :destroyed)
          end

          it_behaves_like "produces a security log", "api_key.deleted" do
            before { service_result }
          end
        end
      end

      context "with force: true and another non-expiring key present" do
        let(:kwargs) { {force: true} }

        before do
          create(:api_key, organization: api_key.organization)
          freeze_time
        end

        it "expires the key" do
          expect { subject }.to change(api_key, :expires_at).to(Time.current)
        end

        it "does not send an API key destroyed email" do
          expect { service_result }.not_to have_enqueued_mail(ApiKeyMailer, :destroyed)
        end
      end
    end
  end
end
