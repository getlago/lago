# frozen_string_literal: true

RSpec.shared_examples "a Premium API endpoint" do
  it "requires a premium license" do
    allow(License).to receive(:premium?).and_return(false)
    subject
    expect(response).to have_http_status(:forbidden)
    expect(json[:error]).to eq("Forbidden")
    expect(json[:code]).to eq("feature_unavailable")
    # License.premium? is called
    # - once for the API key granular permission
    # - once by the PremiumFeatureOnly concerns
    expect(License).to have_received(:premium?).twice
  end
end

RSpec.shared_examples "requires API permission" do |resource, mode|
  describe "permissions", :premium do
    let(:api_key) { organization.api_keys.first }

    before do
      organization.update!(premium_integrations:)
      api_key.update!(permissions: api_key.permissions.merge(resource => modes))
      subject
    end

    context "when organization has 'api_permissions' premium integration" do
      let(:premium_integrations) { organization.premium_integrations.including("api_permissions") }

      context "when API key allows #{mode} action for #{resource}" do
        let(:modes) { [ApiKey::MODES, [mode]].sample }

        it "does not return 403 Forbidden" do
          expect(response).not_to have_http_status(:forbidden)
        end
      end

      context "when API key forbids #{mode} action for #{resource}" do
        let(:modes) { ApiKey::MODES.excluding(mode) }

        it "returns 403 Forbidden" do
          expect(response).to have_http_status(:forbidden)
          expect(json).to match hash_including(code: "#{mode}_action_not_allowed_for_#{resource}")
        end
      end
    end

    context "when organization has no 'api_permissions' premium integration" do
      let(:premium_integrations) { organization.premium_integrations.excluding("api_permissions") }

      context "when API key allows #{mode} action for #{resource}" do
        let(:modes) { [ApiKey::MODES, [mode]].sample }

        it "does not return 403 Forbidden" do
          expect(response).not_to have_http_status(:forbidden)
        end
      end

      context "when API key forbids #{mode} action for #{resource}" do
        let(:modes) { ApiKey::MODES.excluding(mode) }

        it "does not return 403 Forbidden" do
          expect(response).not_to have_http_status(:forbidden)
        end
      end
    end
  end
end
