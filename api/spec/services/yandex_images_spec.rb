require "rails_helper"
require "webmock/rspec"

RSpec.describe YandexImages do
  let(:service) { described_class.new }

  let(:thumbnail_url) { "http://avatars.mds.yandex.net/get-images/12345/thumb?n=13&w=200&h=200" }
  let(:xml_body) do
    <<~XML
      <response>
        <doc>
          <thumbnail-link>#{thumbnail_url}</thumbnail-link>
          <thumbnail-width>200</thumbnail-width>
          <thumbnail-height>150</thumbnail-height>
        </doc>
      </response>
    XML
  end

  let(:api_response_body) do
    { "rawData" => Base64.encode64(xml_body) }.to_json
  end

  before do
    allow(ENV).to receive(:fetch).with("YANDEX_SEARCH_API_KEY").and_return("test-key")
  end

  describe "#search" do
    it "returns url, width, and height from Yandex API" do
      stub_request(:post, "https://searchapi.api.cloud.yandex.net/v2/image/search")
        .to_return(status: 200, body: api_response_body)

      result = service.search("modern office")

      expect(result[:url]).to include("https://")
      expect(result[:url]).to include("n=33")
      expect(result[:url]).to include("w=1200")
      expect(result[:url]).to include("h=1200")
      expect(result[:width]).to eq("200")
      expect(result[:height]).to eq("150")
    end

    it "raises on non-200 response" do
      stub_request(:post, "https://searchapi.api.cloud.yandex.net/v2/image/search")
        .to_return(status: 500, body: "error")

      expect { service.search("fail") }.to raise_error(StandardError)
    end
  end
end
