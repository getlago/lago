# frozen_string_literal: true

RSpec.shared_examples "a premium service" do
  it "requires a premium license" do
    allow(License).to receive(:premium?).and_return(false)
    result = subject
    expect(result).to be_failure
    expect(result.error).to be_a(BaseService::ForbiddenFailure)
    expect(License).to have_received(:premium?).once
  end
end
