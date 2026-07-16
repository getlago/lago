# frozen_string_literal: true

require "rails_helper"

require "rake"

RSpec.describe "recipes:webhook_endpoints:destroy_all" do # rubocop:disable RSpec/DescribeClass
  let(:task) { Rake::Task["recipes:webhook_endpoints:destroy_all"] }
  let(:organization) { create(:organization, api_keys: [], webhook_url: nil) }

  before do
    Rake.application.rake_require("tasks/recipes/webhook_endpoints")
    Rake::Task.define_task(:environment)
    task.reenable
  end

  def stub_stdin(*responses)
    allow($stdin).to receive(:gets).and_return(*responses.map { |r| "#{r}\n" })
  end

  context "when organization is not found" do
    before { stub_stdin("00000000") }

    it "aborts" do
      expect { task.invoke }.to raise_error(SystemExit)
    end
  end

  context "when user does not confirm the organization" do
    before { stub_stdin(organization.id, "n") }

    it "aborts" do
      expect { task.invoke }.to raise_error(SystemExit)
    end
  end

  context "when organization has no webhook endpoints" do
    before { stub_stdin(organization.id, "y") }

    it "finishes without doing anything" do
      expect { task.invoke }.not_to raise_error
    end
  end

  context "when organization has webhook endpoints" do
    let(:endpoint_one) { create(:webhook_endpoint, organization:) }
    let(:endpoint_two) { create(:webhook_endpoint, organization:) }

    before do
      endpoint_one
      endpoint_two
      allow(WebhookEndpoints::DestroyService).to receive(:call).and_call_original
    end

    context "when user confirms" do
      before { stub_stdin(organization.id, "y", "y") }

      it "destroys every endpoint via the destroy service" do
        task.invoke

        expect(WebhookEndpoints::DestroyService).to have_received(:call)
          .with(webhook_endpoint: endpoint_one)
        expect(WebhookEndpoints::DestroyService).to have_received(:call)
          .with(webhook_endpoint: endpoint_two)
        expect(WebhookEndpoint.where(id: [endpoint_one.id, endpoint_two.id])).to be_empty
      end
    end

    context "when DestroyService fails for an endpoint" do
      let(:failure_result) do
        BaseResult.new.tap { |r| r.single_validation_failure!(error_code: "boom") }
      end

      before do
        allow(WebhookEndpoints::DestroyService).to receive(:call).and_return(failure_result)
        stub_stdin(organization.id, "y", "y")
      end

      it "aborts" do
        expect { task.invoke }.to raise_error(SystemExit)
      end
    end

    context "when user declines confirmation" do
      before { stub_stdin(organization.id, "y", "n") }

      it "aborts without destroying endpoints" do
        expect { task.invoke }.to raise_error(SystemExit)
        expect(WebhookEndpoint.where(id: [endpoint_one.id, endpoint_two.id]).count).to eq(2)
      end
    end
  end
end
