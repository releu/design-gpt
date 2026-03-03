require "rails_helper"

RSpec.describe User, type: :model do
  it "has many component_libraries" do
    user = users(:alice)
    expect(user.component_libraries).to include(component_libraries(:example_lib))
    expect(user.component_libraries).to include(component_libraries(:example_icons))
  end

  it "has many designs" do
    expect(users(:alice).designs).to include(designs(:alice_design))
  end

  it "validates auth0_id uniqueness" do
    duplicate = User.new(auth0_id: users(:alice).auth0_id, username: "someone")
    expect(duplicate).not_to be_valid
  end
end
