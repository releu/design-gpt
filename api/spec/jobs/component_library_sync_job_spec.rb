require "rails_helper"

RSpec.describe ComponentLibrarySyncJob, type: :job do
  let(:component_library) { component_libraries(:empty_ds) }

  it "enqueues the job" do
    expect {
      ComponentLibrarySyncJob.perform_later(component_library.id)
    }.to have_enqueued_job(ComponentLibrarySyncJob).with(component_library.id)
  end

  it "calls sync_with_figma on the component library" do
    allow(ComponentLibrary).to receive(:find).with(component_library.id).and_return(component_library)
    allow(component_library).to receive(:sync_with_figma)

    ComponentLibrarySyncJob.perform_now(component_library.id)

    expect(component_library).to have_received(:sync_with_figma)
  end
end
