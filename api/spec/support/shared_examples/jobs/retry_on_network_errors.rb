# frozen_string_literal: true

RSpec.shared_examples "a retryable on network errors job" do
  [
    [LagoHttpClient::HttpError.new(nil, nil, nil), 6],
    [Errno::ECONNREFUSED, 6],
    [Errno::EHOSTUNREACH, 6],
    [Net::OpenTimeout, 6],
    [Net::ReadTimeout, 6],
    [EOFError, 6]
  ].each do |error, attempts|
    error_class = error.is_a?(Class) ? error : error.class

    context "when a #{error_class.name} error is raised" do
      before do
        allow(service_class).to receive(:call).and_raise(error)
      end

      it "raises a #{error_class.name} error and retries" do
        assert_performed_jobs(attempts, only: [described_class]) do
          expect do
            if job_arguments.is_a?(Hash)
              described_class.perform_later(**job_arguments)
            else
              described_class.perform_later(job_arguments)
            end
          end.to raise_error(error_class)
        end
      end
    end
  end
end
