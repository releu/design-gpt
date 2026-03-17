require "rails_helper"

RSpec.describe ImageCache, type: :model do
  let(:yandex_result) { { url: "https://example.com/img.jpg", width: "1200", height: "800" } }

  before do
    allow_any_instance_of(YandexImages).to receive(:search).and_return(yandex_result)
  end

  describe ".search" do
    it "creates a cache record on miss and returns the result" do
      expect { ImageCache.search("modern office") }.to change(ImageCache, :count).by(1)

      result = ImageCache.search("modern office")
      expect(result[:url]).to eq("https://example.com/img.jpg")
    end

    it "returns cached result without calling Yandex on hit" do
      ImageCache.search("cityscape")

      fresh_instance = instance_double(YandexImages)
      allow(YandexImages).to receive(:new).and_return(fresh_instance)
      expect(fresh_instance).not_to receive(:search)

      result = ImageCache.search("cityscape")
      expect(result[:url]).to eq("https://example.com/img.jpg")
    end

    it "normalizes query by stripping and downcasing" do
      ImageCache.search(" Modern Office ")
      record = ImageCache.find_by(query: "modern office")
      expect(record).to be_present
    end

    it "handles race condition with RecordNotUnique" do
      ImageCache.create!(query: "sunset", url: "https://example.com/sunset.jpg", width: "800", height: "600")

      allow(ImageCache).to receive(:find_by).and_return(nil, ImageCache.find_by!(query: "sunset"))
      allow(ImageCache).to receive(:create!).and_raise(ActiveRecord::RecordNotUnique)

      result = ImageCache.search("sunset")
      expect(result[:url]).to eq("https://example.com/sunset.jpg")
    end
  end
end
