# frozen_string_literal: true

RSpec.shared_examples "paper_trail traceable" do
  it { is_expected.to be_versioned }

  it "saves expected membership", versioning: true do
    CurrentContext.membership = "membership/f03f5cd7-9f6f-4d06-85c4-7ea22d65aa5b"
    subject.save!
    expect(subject.versions.last.whodunnit).to eq("membership/f03f5cd7-9f6f-4d06-85c4-7ea22d65aa5b")
    expect(subject.versions.last.lago_version).to eq("test")
    CurrentContext.membership = nil
  end
end
