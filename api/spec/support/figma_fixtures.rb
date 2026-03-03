module FigmaFixtures
  def load_figma_fixture(name)
    path = Rails.root.join("test", "fixtures", "files", "figma_#{name}.json")
    ::JSON.parse(File.read(path))
  end
end

RSpec.configure do |config|
  config.include FigmaFixtures
end
