# frozen_string_literal: true

require "rails_helper"

require "rake"

RSpec.describe "recipes:organizations:terminate" do # rubocop:disable RSpec/DescribeClass
  let(:task) { Rake::Task["recipes:organizations:terminate"] }
  let(:organization) { create(:organization, api_keys: [], webhook_url: nil) }

  before do
    Rake.application.rake_require("tasks/recipes/organizations")
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

  context "when organization has nothing to clean up" do
    before { stub_stdin(organization.id, "y") }

    it "finishes without doing anything" do
      expect { task.invoke }.not_to raise_error
    end
  end

  context "when organization has webhooks, subscriptions, and api keys" do
    let(:customer) { create(:customer, organization:) }
    let(:webhook_endpoint) { create(:webhook_endpoint, organization:) }
    let(:active_sub) { create(:subscription, customer:, organization:) }
    let(:pending_sub) { create(:subscription, :pending, customer:, organization:) }
    let(:api_key) { create(:api_key, organization:) }

    before do
      webhook_endpoint
      active_sub
      pending_sub
      api_key
      allow(WebhookEndpoints::DestroyService).to receive(:call).and_call_original
      allow(ApiKeys::DestroyService).to receive(:call).and_call_original
      allow(Subscriptions::TerminateService).to receive(:call) do |subscription:, **|
        new_status = subscription.pending? ? :canceled : :terminated
        subscription.update!(status: new_status, terminated_at: Time.current)
        BaseResult.new
      end
    end

    context "when user confirms" do
      before { stub_stdin(organization.id, "y", "y") }

      it "destroys webhook endpoints first, then subscriptions, then api keys" do
        call_order = []
        allow(WebhookEndpoints::DestroyService).to receive(:call) do |webhook_endpoint:|
          call_order << [:webhook, webhook_endpoint.id]
          webhook_endpoint.destroy!
          BaseResult.new
        end
        allow(Subscriptions::TerminateService).to receive(:call) do |subscription:, **|
          call_order << [:subscription, subscription.id, subscription.status]
          new_status = subscription.pending? ? :canceled : :terminated
          subscription.update!(status: new_status, terminated_at: Time.current)
          BaseResult.new
        end
        allow(ApiKeys::DestroyService).to receive(:call) do |key, **|
          call_order << [:api_key, key.id]
          key.touch(:expires_at) # rubocop:disable Rails/SkipsModelValidations
          BaseResult.new
        end

        task.invoke

        expect(call_order).to eq([
          [:webhook, webhook_endpoint.id],
          [:subscription, active_sub.id, "active"],
          [:subscription, pending_sub.id, "pending"],
          [:api_key, api_key.id]
        ])
      end

      it "force-expires api keys" do
        task.invoke
        expect(ApiKeys::DestroyService).to have_received(:call).with(api_key, force: true)
      end

      it "terminates subscriptions synchronously" do
        task.invoke
        expect(Subscriptions::TerminateService).to have_received(:call)
          .with(subscription: active_sub, async: false)
        expect(Subscriptions::TerminateService).to have_received(:call)
          .with(subscription: pending_sub, async: false)
      end
    end

    context "when an underlying service fails" do
      let(:failure_result) do
        BaseResult.new.tap { |r| r.single_validation_failure!(error_code: "boom") }
      end

      before do
        allow(Subscriptions::TerminateService).to receive(:call).and_return(failure_result)
        stub_stdin(organization.id, "y", "y")
      end

      it "aborts and leaves api keys untouched" do
        expect { task.invoke }.to raise_error(SystemExit)
        expect(ApiKeys::DestroyService).not_to have_received(:call)
        expect(api_key.reload.expires_at).to be_nil
      end
    end

    context "when user declines confirmation" do
      before { stub_stdin(organization.id, "y", "n") }

      it "aborts without touching anything" do
        expect { task.invoke }.to raise_error(SystemExit)
        expect(WebhookEndpoint.where(id: webhook_endpoint.id)).to exist
        expect(active_sub.reload).to be_active
        expect(pending_sub.reload).to be_pending
        expect(api_key.reload.expires_at).to be_nil
      end
    end
  end
end
