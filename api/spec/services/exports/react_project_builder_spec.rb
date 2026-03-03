require "rails_helper"
require "zip"

RSpec.describe Exports::ReactProjectBuilder do
  let(:design) { designs(:alice_design) }

  describe "#build" do
    it "returns a valid zip file" do
      builder = Exports::ReactProjectBuilder.new(design)
      zip_data = builder.build

      expect(zip_data).to be_present

      # Verify it's a valid zip
      entries = []
      Zip::InputStream.open(StringIO.new(zip_data)) do |io|
        while (entry = io.get_next_entry)
          entries << entry.name
        end
      end

      expect(entries).to include(a_string_matching(/package\.json$/))
      expect(entries).to include(a_string_matching(/index\.html$/))
      expect(entries).to include(a_string_matching(/src\/App\.jsx$/))
      expect(entries).to include(a_string_matching(/src\/main\.jsx$/))
      expect(entries).to include(a_string_matching(/README\.md$/))
    end

    it "includes the design JSX in App.jsx" do
      builder = Exports::ReactProjectBuilder.new(design)
      zip_data = builder.build

      app_jsx = nil
      Zip::InputStream.open(StringIO.new(zip_data)) do |io|
        while (entry = io.get_next_entry)
          if entry.name.end_with?("App.jsx")
            app_jsx = io.read
            break
          end
        end
      end

      expect(app_jsx).to include("VStack")
    end

    it "includes a valid package.json with React deps" do
      builder = Exports::ReactProjectBuilder.new(design)
      zip_data = builder.build

      pkg_json = nil
      Zip::InputStream.open(StringIO.new(zip_data)) do |io|
        while (entry = io.get_next_entry)
          if entry.name.end_with?("package.json")
            pkg_json = JSON.parse(io.read)
            break
          end
        end
      end

      expect(pkg_json["dependencies"]).to have_key("react")
      expect(pkg_json["dependencies"]).to have_key("react-dom")
      expect(pkg_json["scripts"]).to have_key("dev")
    end
  end
end
