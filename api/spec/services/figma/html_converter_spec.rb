require "rails_helper"

RSpec.describe Figma::HtmlConverter do
  # All tests use use_cache: false to avoid filesystem side effects
  def convert(figma_json, **options)
    described_class.new(figma_json, { use_cache: false }.merge(options)).convert
  end

  # =============================================
  # Basic conversion
  # =============================================

  describe "#convert" do
    it "returns error for nil input" do
      result = convert(nil)
      expect(result[:error]).to eq("No Figma JSON provided")
    end

    it "returns error for non-hash input" do
      result = convert("not a hash")
      expect(result[:error]).to eq("No Figma JSON provided")
    end

    it "returns html, css, and full_html keys" do
      json = {
        "id" => "1:1",
        "name" => "TestFrame",
        "type" => "FRAME",
        "size" => { "x" => 200, "y" => 100 },
        "children" => []
      }
      result = convert(json)
      expect(result).to have_key(:html)
      expect(result).to have_key(:css)
      expect(result).to have_key(:full_html)
      expect(result).to have_key(:component_name)
      expect(result[:component_name]).to eq("Testframe")
    end

    it "scopes CSS class names with component name" do
      json = {
        "id" => "1:1",
        "name" => "MyBox",
        "type" => "FRAME",
        "size" => { "x" => 100, "y" => 50 },
        "children" => []
      }
      result = convert(json)
      expect(result[:css]).to include("mybox-root")
      expect(result[:html]).to include("mybox-root")
    end
  end

  # =============================================
  # Frame / container conversion
  # =============================================

  describe "frame conversion" do
    it "generates a div for FRAME nodes" do
      json = {
        "id" => "1:1",
        "name" => "Container",
        "type" => "FRAME",
        "size" => { "x" => 300, "y" => 200 },
        "children" => []
      }
      result = convert(json)
      expect(result[:html]).to include("<div")
      expect(result[:html]).to include("data-component=")
    end

    it "handles nested frames" do
      json = {
        "id" => "1:1",
        "name" => "Parent",
        "type" => "FRAME",
        "layoutMode" => "VERTICAL",
        "size" => { "x" => 300, "y" => 400 },
        "children" => [
          {
            "id" => "1:2",
            "name" => "Child",
            "type" => "FRAME",
            "size" => { "x" => 300, "y" => 100 },
            "children" => []
          }
        ]
      }
      result = convert(json)
      expect(result[:html]).to include("child-")
      expect(result[:css]).to include("flex-direction: column")
    end

    it "renders COMPONENT type same as FRAME" do
      json = {
        "id" => "1:1",
        "name" => "MyComponent",
        "type" => "COMPONENT",
        "size" => { "x" => 200, "y" => 100 },
        "fills" => [],
        "children" => []
      }
      result = convert(json)
      expect(result[:html]).to include("<div")
      # COMPONENT with no fills defaults to white background
      expect(result[:css]).to include("#fff")
    end

    it "handles INSTANCE type" do
      json = {
        "id" => "1:1",
        "name" => "MyInstance",
        "type" => "INSTANCE",
        "componentId" => "2:99",
        "size" => { "x" => 100, "y" => 50 },
        "children" => [
          {
            "id" => "I1:1;2:100",
            "name" => "label",
            "type" => "TEXT",
            "characters" => "Hello",
            "style" => { "fontFamily" => "Inter", "fontSize" => 14 },
            "fills" => [{ "type" => "SOLID", "color" => { "r" => 0, "g" => 0, "b" => 0, "a" => 1 } }]
          }
        ]
      }
      # Without component_resolver, it falls through to rendering children
      result = convert(json)
      expect(result[:html]).to include("Hello")
    end

    it "resolves INSTANCE via component_resolver when provided" do
      resolver = instance_double(Figma::ComponentResolver)
      allow(resolver).to receive(:resolve).with("2:99").and_return({
        html: '<div class="resolved-btn">Button</div>',
        css: ".resolved-btn { color: red; }",
        type: :component
      })

      json = {
        "id" => "1:1",
        "name" => "Wrapper",
        "type" => "FRAME",
        "size" => { "x" => 300, "y" => 100 },
        "children" => [
          {
            "id" => "1:2",
            "name" => "ButtonInstance",
            "type" => "INSTANCE",
            "componentId" => "2:99",
            "size" => { "x" => 100, "y" => 40 },
            "children" => []
          }
        ]
      }

      result = convert(json, component_resolver: resolver)
      expect(result[:html]).to include("resolved-btn")
      expect(result[:html]).to include("Button")
    end
  end

  # =============================================
  # Text conversion
  # =============================================

  describe "text conversion" do
    it "renders TEXT nodes with characters" do
      json = {
        "id" => "1:1",
        "name" => "Label",
        "type" => "FRAME",
        "size" => { "x" => 200, "y" => 40 },
        "children" => [
          {
            "id" => "1:2",
            "name" => "text-label",
            "type" => "TEXT",
            "characters" => "Hello World",
            "style" => { "fontFamily" => "Inter", "fontSize" => 16, "fontWeight" => 400 },
            "fills" => [{ "type" => "SOLID", "color" => { "r" => 0, "g" => 0, "b" => 0, "a" => 1 } }]
          }
        ]
      }
      result = convert(json)
      expect(result[:html]).to include("Hello World")
      expect(result[:css]).to include("font-size: 16px")
      expect(result[:css]).to include('"Inter"')
    end

    it "escapes HTML special characters in text" do
      json = {
        "id" => "1:1",
        "name" => "TextBlock",
        "type" => "FRAME",
        "size" => { "x" => 200, "y" => 40 },
        "children" => [
          {
            "id" => "1:2",
            "name" => "text",
            "type" => "TEXT",
            "characters" => "<script>alert('xss')</script>",
            "style" => {},
            "fills" => []
          }
        ]
      }
      result = convert(json)
      expect(result[:html]).not_to include("<script>")
      expect(result[:html]).to include("&lt;script&gt;")
    end

    it "converts newlines to <br>" do
      json = {
        "id" => "1:1",
        "name" => "MultiLine",
        "type" => "FRAME",
        "size" => { "x" => 200, "y" => 80 },
        "children" => [
          {
            "id" => "1:2",
            "name" => "text",
            "type" => "TEXT",
            "characters" => "Line 1\nLine 2",
            "style" => {},
            "fills" => []
          }
        ]
      }
      result = convert(json)
      expect(result[:html]).to include("Line 1<br>Line 2")
    end

    it "handles styled text with characterStyleOverrides" do
      json = {
        "id" => "1:1",
        "name" => "StyledText",
        "type" => "FRAME",
        "size" => { "x" => 300, "y" => 40 },
        "children" => [
          {
            "id" => "1:2",
            "name" => "rich-text",
            "type" => "TEXT",
            "characters" => "Hello World",
            "style" => { "fontFamily" => "Inter", "fontSize" => 16 },
            "fills" => [{ "type" => "SOLID", "color" => { "r" => 0, "g" => 0, "b" => 0, "a" => 1 } }],
            "characterStyleOverrides" => [0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 1],
            "styleOverrideTable" => {
              "1" => {
                "fontWeight" => 700,
                "fills" => [{ "type" => "SOLID", "color" => { "r" => 1, "g" => 0, "b" => 0, "a" => 1 } }]
              }
            }
          }
        ]
      }
      result = convert(json)
      # "World" should be in a <span> with its own styles
      expect(result[:html]).to include("<span")
      expect(result[:css]).to include("font-weight: 700")
      expect(result[:css]).to include("#ff0000")
    end
  end

  # =============================================
  # Shape / vector conversion
  # =============================================

  describe "shape conversion" do
    it "renders RECTANGLE as a div" do
      json = {
        "id" => "1:1",
        "name" => "ShapeTest",
        "type" => "FRAME",
        "size" => { "x" => 200, "y" => 100 },
        "children" => [
          {
            "id" => "1:2",
            "name" => "box",
            "type" => "RECTANGLE",
            "size" => { "x" => 50, "y" => 50 },
            "fills" => [{ "type" => "SOLID", "color" => { "r" => 1, "g" => 0, "b" => 0, "a" => 1 } }],
            "cornerRadius" => 8
          }
        ]
      }
      result = convert(json)
      expect(result[:css]).to include("width: 50px")
      expect(result[:css]).to include("height: 50px")
      expect(result[:css]).to include("#ff0000")
      expect(result[:css]).to include("border-radius: 8px")
    end

    it "renders ELLIPSE with border-radius 50%" do
      json = {
        "id" => "1:1",
        "name" => "CircleTest",
        "type" => "FRAME",
        "size" => { "x" => 100, "y" => 100 },
        "children" => [
          {
            "id" => "1:2",
            "name" => "circle",
            "type" => "ELLIPSE",
            "size" => { "x" => 40, "y" => 40 },
            "fills" => [{ "type" => "SOLID", "color" => { "r" => 0, "g" => 0.5, "b" => 1, "a" => 1 } }]
          }
        ]
      }
      result = convert(json)
      expect(result[:css]).to include("border-radius: 50%")
    end
  end

  # =============================================
  # Hidden nodes
  # =============================================

  describe "visibility" do
    it "skips invisible nodes entirely" do
      json = {
        "id" => "1:1",
        "name" => "VisTest",
        "type" => "FRAME",
        "size" => { "x" => 200, "y" => 100 },
        "children" => [
          {
            "id" => "1:2",
            "name" => "visible-text",
            "type" => "TEXT",
            "characters" => "Visible",
            "style" => {},
            "fills" => []
          },
          {
            "id" => "1:3",
            "name" => "hidden-text",
            "type" => "TEXT",
            "visible" => false,
            "characters" => "Hidden",
            "style" => {},
            "fills" => []
          }
        ]
      }
      result = convert(json)
      expect(result[:html]).to include("Visible")
      expect(result[:html]).not_to include("Hidden")
    end
  end

  # =============================================
  # Absolute positioning
  # =============================================

  describe "absolute positioning" do
    it "wraps absolutely-positioned children" do
      json = {
        "id" => "1:1",
        "name" => "AbsParent",
        "type" => "FRAME",
        "layoutMode" => "VERTICAL",
        "size" => { "x" => 400, "y" => 300 },
        "absoluteBoundingBox" => { "x" => 0, "y" => 0, "width" => 400, "height" => 300 },
        "children" => [
          {
            "id" => "1:2",
            "name" => "abs-child",
            "type" => "FRAME",
            "layoutPositioning" => "ABSOLUTE",
            "size" => { "x" => 50, "y" => 50 },
            "absoluteBoundingBox" => { "x" => 20, "y" => 30, "width" => 50, "height" => 50 },
            "children" => []
          }
        ]
      }
      result = convert(json)
      expect(result[:css]).to include("position: absolute")
      expect(result[:css]).to include("left: 20px")
      expect(result[:css]).to include("top: 30px")
    end
  end

  # =============================================
  # SVG icon detection
  # =============================================

  describe "SVG icon frames" do
    it "detects icon frames and uses SVG content when provided by client" do
      mock_client = instance_double(Figma::Client)
      allow(mock_client).to receive(:export_svg).and_return({
        "images" => { "1:3" => "https://figma.com/svg/icon.svg" }
      })
      allow(mock_client).to receive(:fetch_svg_content).and_return(
        '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"><path d="M12 0L24 24H0z"/></svg>'
      )

      json = {
        "id" => "1:1",
        "name" => "IconTest",
        "type" => "FRAME",
        "size" => { "x" => 200, "y" => 100 },
        "children" => [
          {
            "id" => "1:3",
            "name" => "arrow-icon",
            "type" => "FRAME",
            "size" => { "x" => 24, "y" => 24 },
            "children" => [
              { "id" => "1:4", "type" => "VECTOR", "name" => "arrow-path" }
            ]
          }
        ]
      }

      result = convert(json, figma_client: mock_client, file_key: "TEST123")
      expect(result[:html]).to include("<svg")
      expect(result[:html]).to include("<span")
    end
  end

  # =============================================
  # Image fills
  # =============================================

  describe "image fills" do
    it "tracks image refs for later fetching" do
      json = {
        "id" => "1:1",
        "name" => "ImageTest",
        "type" => "FRAME",
        "size" => { "x" => 400, "y" => 300 },
        "fills" => [
          { "type" => "IMAGE", "imageRef" => "img_abc123", "scaleMode" => "FILL" }
        ],
        "children" => []
      }

      converter = described_class.new(json, use_cache: false)
      converter.set_image_urls({ "img_abc123" => "https://example.com/image.png" })
      result = converter.convert

      expect(result[:css]).to include("url(https://example.com/image.png)")
      expect(result[:css]).to include("background-size: cover")
      expect(converter.image_refs_found).to include("img_abc123")
    end

    it "falls back to gray when image ref not available" do
      json = {
        "id" => "1:1",
        "name" => "NoImage",
        "type" => "FRAME",
        "size" => { "x" => 200, "y" => 200 },
        "fills" => [
          { "type" => "IMAGE", "imageRef" => "missing_ref" }
        ],
        "children" => []
      }

      converter = described_class.new(json, use_cache: false)
      result = converter.convert

      expect(result[:css]).to include("#e0e0e0")
    end
  end

  # =============================================
  # Font handling
  # =============================================

  describe "font handling" do
    it "generates Google Fonts URL for known fonts" do
      json = {
        "id" => "1:1",
        "name" => "FontTest",
        "type" => "FRAME",
        "size" => { "x" => 200, "y" => 40 },
        "children" => [
          {
            "id" => "1:2",
            "name" => "text",
            "type" => "TEXT",
            "characters" => "Hello",
            "style" => { "fontFamily" => "Inter", "fontSize" => 16 },
            "fills" => []
          }
        ]
      }
      result = convert(json)
      expect(result[:google_fonts_url]).to include("fonts.googleapis.com")
      expect(result[:google_fonts_url]).to include("Inter")
    end

    it "returns nil google_fonts_url when no fonts used" do
      json = {
        "id" => "1:1",
        "name" => "NoFont",
        "type" => "FRAME",
        "size" => { "x" => 100, "y" => 100 },
        "children" => []
      }
      result = convert(json)
      expect(result[:google_fonts_url]).to be_nil
    end
  end

  # =============================================
  # Full HTML output
  # =============================================

  describe "full_html output" do
    it "produces a complete HTML document" do
      json = {
        "id" => "1:1",
        "name" => "FullDoc",
        "type" => "FRAME",
        "size" => { "x" => 400, "y" => 300 },
        "children" => [
          {
            "id" => "1:2",
            "name" => "heading",
            "type" => "TEXT",
            "characters" => "Welcome",
            "style" => { "fontFamily" => "Inter", "fontSize" => 24, "fontWeight" => 700 },
            "fills" => [{ "type" => "SOLID", "color" => { "r" => 0, "g" => 0, "b" => 0, "a" => 1 } }]
          }
        ]
      }
      result = convert(json)

      expect(result[:full_html]).to include("<!DOCTYPE html>")
      expect(result[:full_html]).to include("<html>")
      expect(result[:full_html]).to include("<style>")
      expect(result[:full_html]).to include("Welcome")
      expect(result[:full_html]).to include("fonts.googleapis.com") # Inter is a Google font
    end
  end

  # =============================================
  # Complex real-world-like structure
  # =============================================

  describe "complex structure" do
    it "converts a card-like layout with nested elements" do
      json = {
        "id" => "1:1",
        "name" => "Card",
        "type" => "FRAME",
        "layoutMode" => "VERTICAL",
        "primaryAxisAlignItems" => "MIN",
        "counterAxisAlignItems" => "MIN",
        "itemSpacing" => 16,
        "paddingTop" => 24, "paddingRight" => 24, "paddingBottom" => 24, "paddingLeft" => 24,
        "size" => { "x" => 320, "y" => 200 },
        "fills" => [{ "type" => "SOLID", "color" => { "r" => 1, "g" => 1, "b" => 1, "a" => 1 } }],
        "cornerRadius" => 12,
        "effects" => [
          {
            "type" => "DROP_SHADOW",
            "offset" => { "x" => 0, "y" => 4 },
            "radius" => 16,
            "spread" => 0,
            "color" => { "r" => 0, "g" => 0, "b" => 0, "a" => 0.1 }
          }
        ],
        "children" => [
          {
            "id" => "1:2",
            "name" => "title",
            "type" => "TEXT",
            "characters" => "Card Title",
            "style" => { "fontFamily" => "Inter", "fontSize" => 20, "fontWeight" => 600, "lineHeightPx" => 28 },
            "fills" => [{ "type" => "SOLID", "color" => { "r" => 0.1, "g" => 0.1, "b" => 0.1, "a" => 1 } }]
          },
          {
            "id" => "1:3",
            "name" => "description",
            "type" => "TEXT",
            "characters" => "This is a description of the card that explains its purpose.",
            "style" => { "fontFamily" => "Inter", "fontSize" => 14, "fontWeight" => 400, "lineHeightPx" => 20 },
            "fills" => [{ "type" => "SOLID", "color" => { "r" => 0.4, "g" => 0.4, "b" => 0.4, "a" => 1 } }]
          },
          {
            "id" => "1:4",
            "name" => "divider",
            "type" => "RECTANGLE",
            "size" => { "x" => 272, "y" => 1 },
            "layoutSizingHorizontal" => "FILL",
            "fills" => [{ "type" => "SOLID", "color" => { "r" => 0.9, "g" => 0.9, "b" => 0.9, "a" => 1 } }]
          },
          {
            "id" => "1:5",
            "name" => "actions",
            "type" => "FRAME",
            "layoutMode" => "HORIZONTAL",
            "primaryAxisAlignItems" => "MAX",
            "itemSpacing" => 8,
            "layoutSizingHorizontal" => "FILL",
            "size" => { "x" => 272, "y" => 36 },
            "children" => [
              {
                "id" => "1:6",
                "name" => "btn-text",
                "type" => "TEXT",
                "characters" => "Read More",
                "style" => { "fontFamily" => "Inter", "fontSize" => 14, "fontWeight" => 500 },
                "fills" => [{ "type" => "SOLID", "color" => { "r" => 0, "g" => 0.4, "b" => 1, "a" => 1 } }]
              }
            ]
          }
        ]
      }
      result = convert(json)

      # Verify structure
      expect(result[:html]).to include("Card Title")
      expect(result[:html]).to include("This is a description")
      expect(result[:html]).to include("Read More")

      # Verify layout CSS
      expect(result[:css]).to include("flex-direction: column")
      expect(result[:css]).to include("gap: 16px")
      expect(result[:css]).to include("padding: 24px")
      expect(result[:css]).to include("border-radius: 12px")
      expect(result[:css]).to include("box-shadow:")

      # Verify typography
      expect(result[:css]).to include("font-size: 20px")
      expect(result[:css]).to include("font-size: 14px")
      expect(result[:css]).to include("font-weight: 600")

      # Verify it's valid HTML
      expect(result[:full_html]).to include("<!DOCTYPE html>")
    end
  end
end
