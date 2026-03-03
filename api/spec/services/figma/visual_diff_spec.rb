require 'rails_helper'

RSpec.describe Figma::VisualDiff do
  let(:output_dir) { Rails.root.join("tmp", "visual_diff_test") }

  before do
    FileUtils.mkdir_p(output_dir)
  end

  after do
    FileUtils.rm_rf(output_dir)
  end

  describe ".compare" do
    it "returns error when comparison HTML doesn't exist" do
      result = described_class.compare("/nonexistent/path.html", output_dir: output_dir)
      expect(result[:success]).to be false
      expect(result[:error]).to be_present
    end

    context "with identical images" do
      let(:html_path) { output_dir.join("comparison.html") }

      before do
        # Create a minimal comparison HTML with two identical colored divs
        File.write(html_path, <<~HTML)
          <!DOCTYPE html>
          <html>
          <head><style>
            * { margin: 0; padding: 0; }
            #original-img { width: 100px; height: 100px; background: #ff0000; display: block; }
            #generated-root { width: 100px; height: 100px; background: #ff0000; }
          </style></head>
          <body>
            <div id="original-img" style="width:100px;height:100px;background:#ff0000;"></div>
            <div id="generated-root" style="width:100px;height:100px;background:#ff0000;"></div>
          </body>
          </html>
        HTML
      end

      it "reports low diff percentage for identical content" do
        result = described_class.compare(html_path, output_dir: output_dir)

        # Skip if Chrome/Chromium not available
        if result[:error]&.include?("Could not find")
          skip "Chrome/Chromium not available in this environment"
        end

        expect(result[:diff_percent]).to be <= 5.0
        expect(result[:success]).to be true
        expect(File.exist?(result[:figma_screenshot].to_s)).to be true if result[:figma_screenshot]
        expect(File.exist?(result[:html_screenshot].to_s)).to be true if result[:html_screenshot]
      end
    end

    context "with very different images" do
      let(:html_path) { output_dir.join("comparison_diff.html") }

      before do
        File.write(html_path, <<~HTML)
          <!DOCTYPE html>
          <html>
          <head><style>
            * { margin: 0; padding: 0; }
          </style></head>
          <body>
            <div id="original-img" style="width:100px;height:100px;background:#ff0000;"></div>
            <div id="generated-root" style="width:100px;height:100px;background:#0000ff;"></div>
          </body>
          </html>
        HTML
      end

      it "reports high diff percentage for different content" do
        result = described_class.compare(html_path, output_dir: output_dir)

        if result[:error]&.include?("Could not find")
          skip "Chrome/Chromium not available in this environment"
        end

        expect(result[:diff_percent]).to be > 50.0
        expect(result[:success]).to be false
      end
    end
  end

  describe "pixel_diff (via internal method)" do
    it "reports 0% diff for identical PNG images" do
      # Create two identical images
      img = ChunkyPNG::Image.new(50, 50, ChunkyPNG::Color.rgb(255, 0, 0))
      path1 = output_dir.join("img1.png")
      path2 = output_dir.join("img2.png")
      img.save(path1.to_s)
      img.save(path2.to_s)

      vd = described_class.new("/dev/null", output_dir: output_dir)
      result = vd.send(:pixel_diff, path1.to_s, path2.to_s, output_dir.join("diff.png").to_s)

      expect(result[:diff_percent]).to eq(0.0)
      expect(result[:diff_pixels]).to eq(0)
      expect(result[:total_pixels]).to eq(2500) # 50*50
    end

    it "reports 100% diff for completely different images" do
      img1 = ChunkyPNG::Image.new(50, 50, ChunkyPNG::Color.rgb(255, 0, 0))
      img2 = ChunkyPNG::Image.new(50, 50, ChunkyPNG::Color.rgb(0, 0, 255))
      path1 = output_dir.join("red.png")
      path2 = output_dir.join("blue.png")
      img1.save(path1.to_s)
      img2.save(path2.to_s)

      vd = described_class.new("/dev/null", output_dir: output_dir)
      result = vd.send(:pixel_diff, path1.to_s, path2.to_s, output_dir.join("diff.png").to_s)

      expect(result[:diff_percent]).to eq(100.0)
      expect(result[:diff_pixels]).to eq(2500)
    end

    it "handles images of different sizes by cropping to minimum" do
      img1 = ChunkyPNG::Image.new(100, 100, ChunkyPNG::Color.rgb(255, 0, 0))
      img2 = ChunkyPNG::Image.new(50, 50, ChunkyPNG::Color.rgb(255, 0, 0))
      path1 = output_dir.join("big.png")
      path2 = output_dir.join("small.png")
      img1.save(path1.to_s)
      img2.save(path2.to_s)

      vd = described_class.new("/dev/null", output_dir: output_dir)
      result = vd.send(:pixel_diff, path1.to_s, path2.to_s, output_dir.join("diff.png").to_s)

      expect(result[:width]).to eq(50)
      expect(result[:height]).to eq(50)
      expect(result[:diff_percent]).to eq(0.0)
    end

    it "saves diff image to specified path" do
      img1 = ChunkyPNG::Image.new(10, 10, ChunkyPNG::Color.rgb(255, 0, 0))
      img2 = ChunkyPNG::Image.new(10, 10, ChunkyPNG::Color.rgb(0, 255, 0))
      path1 = output_dir.join("a.png")
      path2 = output_dir.join("b.png")
      diff_path = output_dir.join("diff_out.png")
      img1.save(path1.to_s)
      img2.save(path2.to_s)

      vd = described_class.new("/dev/null", output_dir: output_dir)
      vd.send(:pixel_diff, path1.to_s, path2.to_s, diff_path.to_s)

      expect(File.exist?(diff_path.to_s)).to be true
      diff_img = ChunkyPNG::Image.from_file(diff_path.to_s)
      expect(diff_img.width).to eq(10)
      expect(diff_img.height).to eq(10)
    end
  end
end
