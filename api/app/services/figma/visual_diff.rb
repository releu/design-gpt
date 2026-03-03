# Replaces visual_diff.js — uses Ferrum (Chrome DevTools Protocol) + ChunkyPNG
# for headless screenshot capture and pixel-level image comparison.
#
# Usage:
#   result = Figma::VisualDiff.compare(comparison_html_path, output_dir: dir)
#   result[:diff_percent]  # => 2.34
#   result[:success]       # => true/false (based on threshold)
#
module Figma
  class VisualDiff
    FONT_DIR = Rails.root.join("test", "fonts")
    DEFAULT_THRESHOLD = 5.0      # percent
    PIXEL_THRESHOLD = 0.15       # per-channel tolerance (0..1), matches pixelmatch default

    def self.compare(comparison_html_path, output_dir: nil, threshold: DEFAULT_THRESHOLD)
      new(comparison_html_path, output_dir: output_dir, threshold: threshold).compare
    end

    # Compare a standalone component's Figma screenshot vs its React render.
    # Fetches Figma screenshot via export API, renders React code in headless Chrome,
    # then runs pixel diff. Stores results on the component record.
    def self.compare_component(component)
      output_dir = Rails.root.join("tmp", "visual_diff", "component_#{component.id}")
      FileUtils.mkdir_p(output_dir)

      figma_path = fetch_figma_screenshot(component.figma_file_key, component.node_id, output_dir)
      return nil unless figma_path

      react_path = render_react_screenshot(component.react_code_compiled, output_dir, label: "Component '#{component.name}'")
      return nil unless react_path

      diff_path = File.join(output_dir, "diff.png")
      diff_result = new(nil, output_dir: output_dir).send(:pixel_diff, figma_path, react_path, diff_path)
      diff_percent = diff_result[:diff_percent]&.round(2)

      component.update!(
        match_percent: diff_percent ? (100.0 - diff_percent).round(2) : nil,
        figma_screenshot_path: figma_path.to_s,
        react_screenshot_path: react_path.to_s,
        diff_image_path: diff_path.to_s
      )

      { match_percent: component.match_percent, diff_percent: diff_percent }
    rescue => e
      Rails.logger.error("[VisualDiff] compare_component failed for Component##{component.id} '#{component.name}': #{e.message}")
      nil
    end

    # Compare a component set's default variant
    def self.compare_component_set(component_set)
      variant = component_set.default_variant
      return nil unless variant&.react_code_compiled.present?

      output_dir = Rails.root.join("tmp", "visual_diff", "component_set_#{component_set.id}")
      FileUtils.mkdir_p(output_dir)

      figma_path = fetch_figma_screenshot(component_set.figma_file_key, component_set.node_id, output_dir)
      return nil unless figma_path

      react_path = render_react_screenshot(variant.react_code_compiled, output_dir, label: "ComponentSet '#{component_set.name}'")
      return nil unless react_path

      diff_path = File.join(output_dir, "diff.png")
      diff_result = new(nil, output_dir: output_dir).send(:pixel_diff, figma_path, react_path, diff_path)
      diff_percent = diff_result[:diff_percent]&.round(2)

      variant.update!(
        match_percent: diff_percent ? (100.0 - diff_percent).round(2) : nil,
        figma_screenshot_path: figma_path.to_s,
        react_screenshot_path: react_path.to_s,
        diff_image_path: diff_path.to_s
      )

      { match_percent: variant.match_percent, diff_percent: diff_percent }
    rescue => e
      Rails.logger.error("[VisualDiff] compare_component_set failed for ComponentSet##{component_set.id}: #{e.message}")
      nil
    end

    # Fetch a Figma node screenshot via the export API
    def self.fetch_figma_screenshot(file_key, node_id, output_dir)
      return nil unless file_key.present? && node_id.present?

      figma = Figma::Client.new(ENV["FIGMA_TOKEN"])
      response = figma.export_png(file_key, node_id)
      image_url = response.dig("images", node_id)
      return nil unless image_url.present?

      image_data = figma.fetch_binary_content(image_url)
      path = File.join(output_dir, "figma.png")
      File.binwrite(path, image_data)
      path
    rescue => e
      Rails.logger.error("[VisualDiff] fetch_figma_screenshot failed: #{e.message}")
      nil
    end

    # Render compiled React code in headless Chrome and screenshot it
    def self.render_react_screenshot(compiled_code, output_dir, label: nil)
      return nil unless compiled_code.present?

      html = <<~HTML
        <!DOCTYPE html>
        <html><head>
          <meta charset="UTF-8">
          <script src="https://unpkg.com/react@18/umd/react.production.min.js"></script>
          <script src="https://unpkg.com/react-dom@18/umd/react-dom.production.min.js"></script>
          <style>body { margin: 0; padding: 16px; background: white; }</style>
        </head><body>
          <div id="root"></div>
          <script>
            #{compiled_code}
            var componentName = Object.keys(window).find(function(k) {
              return typeof window[k] === 'function' && k.match(/^[A-Z]/);
            });
            if (componentName) {
              var root = ReactDOM.createRoot(document.getElementById('root'));
              root.render(React.createElement(window[componentName], null));
            }
          </script>
        </body></html>
      HTML

      html_path = File.join(output_dir, "react_render.html")
      File.write(html_path, html)

      browser = Ferrum::Browser.new(
        headless: true,
        window_size: [800, 600],
        browser_options: { "no-sandbox" => nil, "disable-setuid-sandbox" => nil }
      )

      begin
        page = browser.create_page
        page.go_to("file://#{html_path}")
        sleep 1

        rect = page.evaluate("document.getElementById('root').getBoundingClientRect().toJSON()")
        if rect["height"].to_f < 1 || rect["width"].to_f < 1
          Rails.logger.warn("[VisualDiff] render_react_screenshot skipped#{label ? " for #{label}" : ""}: #root has 0 dimensions (#{rect["width"]}x#{rect["height"]})")
          return nil
        end

        path = File.join(output_dir, "react.png")
        page.screenshot(path: path, selector: "#root")
        path
      ensure
        browser.quit
      end
    rescue => e
      Rails.logger.error("[VisualDiff] render_react_screenshot failed#{label ? " for #{label}" : ""}: #{e.message}")
      nil
    end

    def initialize(comparison_html_path, output_dir: nil, threshold: DEFAULT_THRESHOLD)
      @html_path = comparison_html_path.to_s
      @output_dir = output_dir || Rails.root.join("tmp", "figma2react_test")
      @threshold = threshold

      FileUtils.mkdir_p(@output_dir)
    end

    def compare
      browser = Ferrum::Browser.new(
        headless: true,
        window_size: [4000, 3000],
        browser_options: {
          "no-sandbox" => nil,
          "disable-setuid-sandbox" => nil
        }
      )

      begin
        page = browser.create_page
        page.go_to("file://#{@html_path}")

        # Inject local font CSS
        font_css = generate_font_face_css
        page.execute("(function() { var s = document.createElement('style'); s.textContent = #{font_css.to_json}; document.head.appendChild(s); })()")

        # Wait for fonts to load + render
        page.evaluate("document.fonts.ready")
        sleep 1

        # Screenshot the original Figma export image
        original_path = File.join(@output_dir, "screenshot_original.png")
        screenshot_element(page, "#original-img", original_path)

        # Screenshot the generated HTML
        generated_path = File.join(@output_dir, "screenshot_generated.png")
        screenshot_element(page, "#generated-root", generated_path)

        # Pixel diff
        diff_path = File.join(@output_dir, "screenshot_diff.png")
        diff_result = pixel_diff(original_path, generated_path, diff_path)

        diff_percent = diff_result[:diff_percent]

        {
          success: diff_percent <= @threshold,
          diff_percent: diff_percent.round(2),
          diff_pixels: diff_result[:diff_pixels],
          total_pixels: diff_result[:total_pixels],
          width: diff_result[:width],
          height: diff_result[:height],
          figma_screenshot: original_path,
          html_screenshot: generated_path,
          diff_image: diff_path,
          error: diff_percent > @threshold ? "Visual diff #{diff_percent.round(2)}% exceeds #{@threshold}% threshold" : nil
        }
      ensure
        browser.quit
      end
    rescue => e
      { success: false, error: e.message }
    end

    private

    def screenshot_element(page, selector, output_path)
      rect = page.evaluate("document.querySelector('#{selector}').getBoundingClientRect().toJSON()")
      if rect["height"].to_f < 1 || rect["width"].to_f < 1
        raise "Element #{selector} has 0 dimensions (#{rect["width"]}x#{rect["height"]})"
      end

      page.screenshot(path: output_path, selector: selector)
      output_path
    end

    def pixel_diff(img1_path, img2_path, diff_path)
      img1 = ChunkyPNG::Image.from_file(img1_path)
      img2 = ChunkyPNG::Image.from_file(img2_path)

      # Use the smaller dimensions (crop to common area)
      width = [img1.width, img2.width].min
      height = [img1.height, img2.height].min

      img1 = img1.crop(0, 0, width, height) if img1.width != width || img1.height != height
      img2 = img2.crop(0, 0, width, height) if img2.width != width || img2.height != height

      diff_image = ChunkyPNG::Image.new(width, height, ChunkyPNG::Color::TRANSPARENT)
      diff_pixels = 0

      # Scale threshold to 0-255 range
      channel_threshold = (PIXEL_THRESHOLD * 255).to_i

      height.times do |y|
        width.times do |x|
          c1 = img1[x, y]
          c2 = img2[x, y]

          if pixels_differ?(c1, c2, channel_threshold)
            diff_pixels += 1
            # Red highlight for diff pixels
            diff_image[x, y] = ChunkyPNG::Color.rgba(255, 0, 0, 180)
          else
            # Dim version of original for context
            r = ChunkyPNG::Color.r(c1)
            g = ChunkyPNG::Color.g(c1)
            b = ChunkyPNG::Color.b(c1)
            diff_image[x, y] = ChunkyPNG::Color.rgba(
              (r * 0.3).to_i,
              (g * 0.3).to_i,
              (b * 0.3).to_i,
              255
            )
          end
        end
      end

      diff_image.save(diff_path)

      total_pixels = width * height
      diff_percent = total_pixels > 0 ? (diff_pixels.to_f / total_pixels) * 100 : 0.0

      {
        diff_pixels: diff_pixels,
        total_pixels: total_pixels,
        diff_percent: diff_percent,
        width: width,
        height: height
      }
    end

    def pixels_differ?(c1, c2, threshold)
      dr = (ChunkyPNG::Color.r(c1) - ChunkyPNG::Color.r(c2)).abs
      dg = (ChunkyPNG::Color.g(c1) - ChunkyPNG::Color.g(c2)).abs
      db = (ChunkyPNG::Color.b(c1) - ChunkyPNG::Color.b(c2)).abs
      da = (ChunkyPNG::Color.a(c1) - ChunkyPNG::Color.a(c2)).abs

      # Any channel exceeding threshold counts as different
      dr > threshold || dg > threshold || db > threshold || da > threshold
    end

    def generate_font_face_css
      css = ""
      return css unless Dir.exist?(FONT_DIR)

      # Scan font directories and generate @font-face rules
      Dir.glob(FONT_DIR.join("*")).select { |d| File.directory?(d) }.each do |font_dir|
        family_name = File.basename(font_dir)
        generate_font_faces_for_family(font_dir, family_name, css_buf = "")
        css += css_buf
      end

      css
    end

    def generate_font_faces_for_family(font_dir, family_name, css)
      weights = {
        "Thin" => 100, "ExtraLight" => 200, "Light" => 300,
        "Regular" => 400, "Medium" => 500, "SemiBold" => 600,
        "Bold" => 700, "ExtraBold" => 800, "Heavy" => 800,
        "Black" => 900
      }

      # Check for fonts.css first
      fonts_css = File.join(font_dir, "fonts.css")
      if File.exist?(fonts_css)
        raw = File.read(fonts_css)
        # Rewrite relative URLs to absolute file:// paths
        raw = raw.gsub(/url\("([^"]+)"\)/) do |match|
          url = $1
          if url.start_with?("http", "file://")
            match
          else
            "url(\"file://#{File.join(font_dir, url)}\")"
          end
        end
        css << raw

        # Also alias "X Web" -> "X" if the font family differs from dir name
        declared_family = raw.match(/font-family:\s*"([^"]+)"/)&.[](1)
        if declared_family && declared_family != family_name
          css << raw.gsub("\"#{declared_family}\"", "\"#{family_name}\"")
        end
        # Also add a "Family Web" alias (common Figma pattern)
        web_name = "#{family_name} Web"
        css << raw.gsub("\"#{declared_family || family_name}\"", "\"#{web_name}\"")
        return
      end

      # Auto-detect from font files
      Dir.glob(File.join(font_dir, "*.{woff2,woff,ttf}")).each do |font_file|
        ext = File.extname(font_file).delete(".")
        filename = File.basename(font_file, ".*")
        format = case ext
                 when "woff2" then "woff2"
                 when "woff" then "woff"
                 when "ttf" then "truetype"
                 end

        weight = 400
        weights.each do |name, val|
          if filename.downcase.include?(name.downcase)
            weight = val
            break
          end
        end

        font_style = filename.downcase.include?("italic") ? "italic" : "normal"

        [family_name, "#{family_name} Web"].each do |name|
          css << <<~CSS
            @font-face {
              font-family: "#{name}";
              src: url("file://#{font_file}") format("#{format}");
              font-weight: #{weight};
              font-style: #{font_style};
            }
          CSS
        end
      end
    end
  end
end
