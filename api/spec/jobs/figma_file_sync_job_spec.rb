require "rails_helper"

RSpec.describe FigmaFileSyncJob, type: :job do
  let(:figma_file) { figma_files(:empty_ds) }

  it "enqueues the job" do
    expect {
      FigmaFileSyncJob.perform_later(figma_file.id)
    }.to have_enqueued_job(FigmaFileSyncJob).with(figma_file.id)
  end

  it "calls sync_with_figma on the figma file" do
    allow(FigmaFile).to receive(:find).with(figma_file.id).and_return(figma_file)
    allow(figma_file).to receive(:sync_with_figma)

    FigmaFileSyncJob.perform_now(figma_file.id)

    expect(figma_file).to have_received(:sync_with_figma)
  end
end
