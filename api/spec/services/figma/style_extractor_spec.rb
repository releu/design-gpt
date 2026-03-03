require "rails_helper"

# Test harness — include the module into a simple class
class StyleExtractorHarness
  include Figma::StyleExtractor
end

RSpec.describe Figma::StyleExtractor do
  subject(:extractor) { StyleExtractorHarness.new }

  # =============================================
  # figma_color_to_css
  # =============================================

  describe "#figma_color_to_css" do
    it "converts solid black to hex" do
      color = { "r" => 0, "g" => 0, "b" => 0, "a" => 1 }
      expect(extractor.figma_color_to_css(color)).to eq("#000000")
    end

    it "converts solid white to hex" do
      color = { "r" => 1, "g" => 1, "b" => 1, "a" => 1 }
      expect(extractor.figma_color_to_css(color)).to eq("#ffffff")
    end

    it "converts a color with alpha < 1 to rgba" do
      color = { "r" => 1, "g" => 0, "b" => 0, "a" => 0.5 }
      expect(extractor.figma_color_to_css(color)).to eq("rgba(255, 0, 0, 0.5)")
    end

    it "applies fill_opacity to alpha channel" do
      color = { "r" => 0, "g" => 0, "b" => 1, "a" => 1 }
      result = extractor.figma_color_to_css(color, 0.5)
      expect(result).to eq("rgba(0, 0, 255, 0.5)")
    end

    it "multiplies color alpha with fill_opacity" do
      color = { "r" => 0, "g" => 0, "b" => 0, "a" => 0.5 }
      result = extractor.figma_color_to_css(color, 0.5)
      expect(result).to eq("rgba(0, 0, 0, 0.25)")
    end

    it "returns transparent for nil color" do
      expect(extractor.figma_color_to_css(nil)).to eq("transparent")
    end
  end

  # =============================================
  # figma_align_to_css
  # =============================================

  describe "#figma_align_to_css" do
    it "maps MIN to flex-start" do
      expect(extractor.figma_align_to_css("MIN")).to eq("flex-start")
    end

    it "maps CENTER to center" do
      expect(extractor.figma_align_to_css("CENTER")).to eq("center")
    end

    it "maps MAX to flex-end" do
      expect(extractor.figma_align_to_css("MAX")).to eq("flex-end")
    end

    it "maps SPACE_BETWEEN to space-between" do
      expect(extractor.figma_align_to_css("SPACE_BETWEEN")).to eq("space-between")
    end

    it "defaults unknown alignment to flex-start" do
      expect(extractor.figma_align_to_css("UNKNOWN")).to eq("flex-start")
    end
  end

  # =============================================
  # extract_frame_styles
  # =============================================

  describe "#extract_frame_styles" do
    it "sets flex direction for horizontal auto-layout" do
      node = {
        "layoutMode" => "HORIZONTAL",
        "primaryAxisAlignItems" => "MIN",
        "counterAxisAlignItems" => "MIN",
        "size" => { "x" => 200, "y" => 50 }
      }
      styles = extractor.extract_frame_styles(node)
      expect(styles["display"]).to eq("flex")
      expect(styles["flex-direction"]).to eq("row")
    end

    it "sets flex direction for vertical auto-layout" do
      node = {
        "layoutMode" => "VERTICAL",
        "primaryAxisAlignItems" => "CENTER",
        "counterAxisAlignItems" => "CENTER",
        "size" => { "x" => 200, "y" => 300 }
      }
      styles = extractor.extract_frame_styles(node)
      expect(styles["display"]).to eq("flex")
      expect(styles["flex-direction"]).to eq("column")
      expect(styles["justify-content"]).to eq("center")
      expect(styles["align-items"]).to eq("center")
    end

    it "sets gap from itemSpacing" do
      node = {
        "layoutMode" => "HORIZONTAL",
        "itemSpacing" => 12,
        "size" => { "x" => 200, "y" => 50 }
      }
      styles = extractor.extract_frame_styles(node)
      expect(styles["gap"]).to eq("12px")
    end

    it "omits gap when itemSpacing is 0" do
      node = {
        "layoutMode" => "HORIZONTAL",
        "itemSpacing" => 0,
        "size" => { "x" => 200, "y" => 50 }
      }
      styles = extractor.extract_frame_styles(node)
      expect(styles).not_to have_key("gap")
    end

    it "sets flex-wrap when layoutWrap is WRAP" do
      node = {
        "layoutMode" => "HORIZONTAL",
        "layoutWrap" => "WRAP",
        "counterAxisSpacing" => 8,
        "size" => { "x" => 200, "y" => 50 }
      }
      styles = extractor.extract_frame_styles(node)
      expect(styles["flex-wrap"]).to eq("wrap")
      expect(styles["row-gap"]).to eq("8px")
    end

    it "sets fixed dimensions for non-layout frames" do
      node = {
        "size" => { "x" => 300, "y" => 150 }
      }
      styles = extractor.extract_frame_styles(node)
      expect(styles["width"]).to eq("300px")
      expect(styles["height"]).to eq("150px")
    end

    it "handles FILL sizing modes" do
      node = {
        "layoutMode" => "HORIZONTAL",
        "layoutSizingHorizontal" => "FILL",
        "layoutSizingVertical" => "FILL",
        "size" => { "x" => 200, "y" => 50 }
      }
      styles = extractor.extract_frame_styles(node)
      expect(styles["width"]).to eq("100%")
      expect(styles["height"]).to eq("100%")
    end

    it "handles HUG sizing" do
      node = {
        "layoutMode" => "HORIZONTAL",
        "layoutSizingHorizontal" => "HUG",
        "layoutSizingVertical" => "HUG",
        "size" => { "x" => 200, "y" => 50 }
      }
      styles = extractor.extract_frame_styles(node)
      expect(styles["width"]).to eq("fit-content")
      expect(styles["height"]).to eq("fit-content")
    end

    it "sets flex-grow when layoutGrow > 0" do
      node = {
        "layoutGrow" => 1,
        "size" => { "x" => 100, "y" => 50 }
      }
      styles = extractor.extract_frame_styles(node)
      expect(styles["flex-grow"]).to eq("1")
      expect(styles["flex-basis"]).to eq("0")
    end

    it "sets overflow hidden when clipsContent is true" do
      node = { "clipsContent" => true, "size" => { "x" => 100, "y" => 100 } }
      styles = extractor.extract_frame_styles(node)
      expect(styles["overflow"]).to eq("hidden")
    end

    it "sets opacity when < 1" do
      node = { "opacity" => 0.5, "size" => { "x" => 100, "y" => 100 } }
      styles = extractor.extract_frame_styles(node)
      expect(styles["opacity"]).to eq("0.5")
    end

    it "sets display none for invisible nodes" do
      node = { "visible" => false, "size" => { "x" => 100, "y" => 100 } }
      styles = extractor.extract_frame_styles(node)
      expect(styles["display"]).to eq("none")
    end

    it "defaults COMPONENT type to white background when no fills" do
      node = { "type" => "COMPONENT", "fills" => [], "size" => { "x" => 100, "y" => 100 } }
      styles = extractor.extract_frame_styles(node)
      expect(styles["background"]).to eq("#fff")
    end

    it "always includes box-sizing border-box" do
      node = { "size" => { "x" => 100, "y" => 100 } }
      styles = extractor.extract_frame_styles(node)
      expect(styles["box-sizing"]).to eq("border-box")
    end
  end

  # =============================================
  # extract_text_styles
  # =============================================

  describe "#extract_text_styles" do
    it "extracts font properties" do
      node = {
        "style" => {
          "fontFamily" => "Inter",
          "fontSize" => 16,
          "fontWeight" => 600,
          "lineHeightPx" => 24
        },
        "fills" => [
          { "type" => "SOLID", "color" => { "r" => 0, "g" => 0, "b" => 0, "a" => 1 } }
        ]
      }
      styles = extractor.extract_text_styles(node)
      expect(styles["font-family"]).to eq('"Inter", sans-serif')
      expect(styles["font-size"]).to eq("16px")
      expect(styles["font-weight"]).to eq("600")
      expect(styles["line-height"]).to eq("24px")
      expect(styles["color"]).to eq("#000000")
    end

    it "handles percentage line height" do
      node = {
        "style" => { "lineHeightPercentFontSize" => 150 },
        "fills" => []
      }
      styles = extractor.extract_text_styles(node)
      expect(styles["line-height"]).to eq("1.5")
    end

    it "handles AUTO line height" do
      node = {
        "style" => { "lineHeightUnit" => "AUTO" },
        "fills" => []
      }
      styles = extractor.extract_text_styles(node)
      expect(styles["line-height"]).to eq("normal")
    end

    it "sets letter-spacing" do
      node = {
        "style" => { "letterSpacing" => 1.5 },
        "fills" => []
      }
      styles = extractor.extract_text_styles(node)
      expect(styles["letter-spacing"]).to eq("1.5px")
    end

    it "ignores zero letter-spacing" do
      node = {
        "style" => { "letterSpacing" => 0 },
        "fills" => []
      }
      styles = extractor.extract_text_styles(node)
      expect(styles).not_to have_key("letter-spacing")
    end

    it "handles text-align horizontal" do
      node = {
        "style" => { "textAlignHorizontal" => "CENTER" },
        "fills" => []
      }
      styles = extractor.extract_text_styles(node)
      expect(styles["text-align"]).to eq("center")
    end

    it "handles vertical alignment CENTER" do
      node = {
        "style" => { "textAlignVertical" => "CENTER" },
        "fills" => []
      }
      styles = extractor.extract_text_styles(node)
      expect(styles["display"]).to eq("flex")
      expect(styles["align-items"]).to eq("center")
    end

    it "handles text decoration underline" do
      node = {
        "style" => { "textDecoration" => "UNDERLINE" },
        "fills" => []
      }
      styles = extractor.extract_text_styles(node)
      expect(styles["text-decoration"]).to eq("underline")
    end

    it "handles text decoration strikethrough" do
      node = {
        "style" => { "textDecoration" => "STRIKETHROUGH" },
        "fills" => []
      }
      styles = extractor.extract_text_styles(node)
      expect(styles["text-decoration"]).to eq("line-through")
    end

    it "handles text-transform cases" do
      %w[UPPER LOWER TITLE].zip(%w[uppercase lowercase capitalize]).each do |figma, css|
        node = { "style" => { "textCase" => figma }, "fills" => [] }
        styles = extractor.extract_text_styles(node)
        expect(styles["text-transform"]).to eq(css), "Expected #{figma} -> #{css}"
      end
    end

    it "handles SMALL_CAPS" do
      node = { "style" => { "textCase" => "SMALL_CAPS" }, "fills" => [] }
      styles = extractor.extract_text_styles(node)
      expect(styles["font-variant"]).to eq("small-caps")
    end

    it "handles italic" do
      node = { "style" => { "italic" => true }, "fills" => [] }
      styles = extractor.extract_text_styles(node)
      expect(styles["font-style"]).to eq("italic")
    end

    it "handles text truncation with single line" do
      node = {
        "textTruncation" => "ENDING",
        "style" => {},
        "fills" => []
      }
      styles = extractor.extract_text_styles(node)
      expect(styles["overflow"]).to eq("hidden")
      expect(styles["text-overflow"]).to eq("ellipsis")
      expect(styles["white-space"]).to eq("nowrap")
    end

    it "handles text truncation with maxLines > 1" do
      node = {
        "textTruncation" => "ENDING",
        "maxLines" => 3,
        "style" => {},
        "fills" => []
      }
      styles = extractor.extract_text_styles(node)
      expect(styles["display"]).to eq("-webkit-box")
      expect(styles["-webkit-line-clamp"]).to eq("3")
      expect(styles["-webkit-box-orient"]).to eq("vertical")
    end

    it "handles WIDTH_AND_HEIGHT auto resize" do
      node = {
        "style" => { "textAutoResize" => "WIDTH_AND_HEIGHT" },
        "fills" => []
      }
      styles = extractor.extract_text_styles(node)
      expect(styles["white-space"]).to eq("nowrap")
    end

    it "handles FILL sizing" do
      node = {
        "layoutSizingHorizontal" => "FILL",
        "layoutSizingVertical" => "FILL",
        "style" => {},
        "fills" => []
      }
      styles = extractor.extract_text_styles(node)
      expect(styles["width"]).to eq("100%")
      expect(styles["height"]).to eq("100%")
    end

    it "always includes word-wrap and position" do
      node = { "style" => {}, "fills" => [] }
      styles = extractor.extract_text_styles(node)
      expect(styles["word-wrap"]).to eq("break-word")
      expect(styles["overflow-wrap"]).to eq("break-word")
      expect(styles["position"]).to eq("relative")
      expect(styles["flex-shrink"]).to eq("0")
    end
  end

  # =============================================
  # extract_shape_styles
  # =============================================

  describe "#extract_shape_styles" do
    it "sets dimensions from size" do
      node = {
        "size" => { "x" => 24, "y" => 24 },
        "fills" => [],
        "type" => "RECTANGLE"
      }
      styles = extractor.extract_shape_styles(node)
      expect(styles["width"]).to eq("24px")
      expect(styles["height"]).to eq("24px")
    end

    it "sets border-radius 50% for ELLIPSE" do
      node = {
        "type" => "ELLIPSE",
        "size" => { "x" => 40, "y" => 40 },
        "fills" => []
      }
      styles = extractor.extract_shape_styles(node)
      expect(styles["border-radius"]).to eq("50%")
    end

    it "handles LINE type" do
      node = {
        "type" => "LINE",
        "size" => { "x" => 100, "y" => 1 },
        "fills" => []
      }
      styles = extractor.extract_shape_styles(node)
      expect(styles["height"]).to eq("0")
      expect(styles["border-top"]).to eq("1px solid")
    end

    it "handles rotation" do
      node = {
        "type" => "RECTANGLE",
        "rotation" => 45,
        "size" => { "x" => 50, "y" => 50 },
        "fills" => []
      }
      styles = extractor.extract_shape_styles(node)
      expect(styles["transform"]).to eq("rotate(-45deg)")
    end

    it "handles FILL sizing" do
      node = {
        "type" => "RECTANGLE",
        "layoutSizingHorizontal" => "FILL",
        "layoutSizingVertical" => "FILL",
        "size" => { "x" => 50, "y" => 50 },
        "fills" => []
      }
      styles = extractor.extract_shape_styles(node)
      expect(styles["width"]).to eq("100%")
      expect(styles["height"]).to eq("100%")
    end
  end

  # =============================================
  # extract_absolute_position
  # =============================================

  describe "#extract_absolute_position" do
    it "calculates offset relative to parent" do
      node = { "absoluteBoundingBox" => { "x" => 120, "y" => 250 } }
      parent = { "absoluteBoundingBox" => { "x" => 100, "y" => 200 } }
      styles = extractor.extract_absolute_position(node, parent)
      expect(styles["left"]).to eq("20px")
      expect(styles["top"]).to eq("50px")
    end

    it "returns empty when bboxes are missing" do
      expect(extractor.extract_absolute_position({}, {})).to be_empty
    end
  end

  # =============================================
  # add_padding
  # =============================================

  describe "#add_padding" do
    it "generates shorthand for uniform padding" do
      styles = {}
      node = { "paddingTop" => 16, "paddingRight" => 16, "paddingBottom" => 16, "paddingLeft" => 16 }
      extractor.add_padding(styles, node)
      expect(styles["padding"]).to eq("16px")
    end

    it "generates 2-value shorthand for symmetric padding" do
      styles = {}
      node = { "paddingTop" => 8, "paddingRight" => 16, "paddingBottom" => 8, "paddingLeft" => 16 }
      extractor.add_padding(styles, node)
      expect(styles["padding"]).to eq("8px 16px")
    end

    it "generates 4-value for asymmetric padding" do
      styles = {}
      node = { "paddingTop" => 4, "paddingRight" => 8, "paddingBottom" => 12, "paddingLeft" => 16 }
      extractor.add_padding(styles, node)
      expect(styles["padding"]).to eq("4px 8px 12px 16px")
    end

    it "omits padding when all zero" do
      styles = {}
      node = { "paddingTop" => 0, "paddingRight" => 0, "paddingBottom" => 0, "paddingLeft" => 0 }
      extractor.add_padding(styles, node)
      expect(styles).not_to have_key("padding")
    end
  end

  # =============================================
  # add_fills
  # =============================================

  describe "#add_fills" do
    it "converts a single solid fill" do
      styles = {}
      fills = [{ "type" => "SOLID", "color" => { "r" => 1, "g" => 0, "b" => 0, "a" => 1 } }]
      extractor.add_fills(styles, fills)
      expect(styles["background"]).to eq("#ff0000")
    end

    it "ignores invisible fills" do
      styles = {}
      fills = [{ "type" => "SOLID", "visible" => false, "color" => { "r" => 1, "g" => 0, "b" => 0, "a" => 1 } }]
      extractor.add_fills(styles, fills)
      expect(styles).not_to have_key("background")
    end

    it "handles multiple fills (bottom layer as solid, upper as linear-gradient)" do
      styles = {}
      fills = [
        { "type" => "SOLID", "color" => { "r" => 1, "g" => 0, "b" => 0, "a" => 0.5 } },
        { "type" => "SOLID", "color" => { "r" => 0, "g" => 0, "b" => 1, "a" => 1 } }
      ]
      extractor.add_fills(styles, fills)
      bg = styles["background"]
      # Multiple fills: bottom layer is solid, upper is wrapped in linear-gradient
      expect(bg).to include("#0000ff") # bottom layer solid
      expect(bg).to include("linear-gradient") # upper layer wrapped
    end

    it "generates linear gradient" do
      styles = {}
      fills = [
        {
          "type" => "GRADIENT_LINEAR",
          "gradientHandlePositions" => [
            { "x" => 0.5, "y" => 0 },
            { "x" => 0.5, "y" => 1 }
          ],
          "gradientStops" => [
            { "color" => { "r" => 1, "g" => 0, "b" => 0, "a" => 1 }, "position" => 0 },
            { "color" => { "r" => 0, "g" => 0, "b" => 1, "a" => 1 }, "position" => 1 }
          ]
        }
      ]
      extractor.add_fills(styles, fills)
      expect(styles["background"]).to match(/linear-gradient/)
      expect(styles["background"]).to include("#ff0000")
      expect(styles["background"]).to include("#0000ff")
    end

    it "handles nil fills gracefully" do
      styles = {}
      extractor.add_fills(styles, nil)
      expect(styles).not_to have_key("background")
    end
  end

  # =============================================
  # add_strokes
  # =============================================

  describe "#add_strokes" do
    it "generates center stroke as border" do
      node = {
        "strokes" => [{ "type" => "SOLID", "color" => { "r" => 0, "g" => 0, "b" => 0, "a" => 1 } }],
        "strokeWeight" => 2,
        "strokeAlign" => "CENTER"
      }
      styles = {}
      extractor.add_strokes(styles, node)
      expect(styles["border"]).to eq("2px solid #000000")
    end

    it "generates inside stroke as inset box-shadow" do
      node = {
        "strokes" => [{ "type" => "SOLID", "color" => { "r" => 0, "g" => 0, "b" => 0, "a" => 1 } }],
        "strokeWeight" => 1,
        "strokeAlign" => "INSIDE"
      }
      styles = {}
      extractor.add_strokes(styles, node)
      expect(styles["box-shadow"]).to include("inset")
    end

    it "generates outside stroke as box-shadow" do
      node = {
        "strokes" => [{ "type" => "SOLID", "color" => { "r" => 0, "g" => 0, "b" => 0, "a" => 1 } }],
        "strokeWeight" => 1,
        "strokeAlign" => "OUTSIDE"
      }
      styles = {}
      extractor.add_strokes(styles, node)
      expect(styles["box-shadow"]).to eq("0 0 0 1px #000000")
    end

    it "handles individual stroke weights" do
      node = {
        "strokes" => [{ "type" => "SOLID", "color" => { "r" => 0, "g" => 0, "b" => 0, "a" => 1 } }],
        "strokeWeight" => 1,
        "strokeAlign" => "CENTER",
        "individualStrokeWeights" => { "top" => 1, "right" => 0, "bottom" => 2, "left" => 0 }
      }
      styles = {}
      extractor.add_strokes(styles, node)
      expect(styles["border-top"]).to eq("1px solid #000000")
      expect(styles["border-bottom"]).to eq("2px solid #000000")
      expect(styles).not_to have_key("border-right")
      expect(styles).not_to have_key("border-left")
    end

    it "handles dashed strokes" do
      node = {
        "strokes" => [{ "type" => "SOLID", "color" => { "r" => 0, "g" => 0, "b" => 0, "a" => 1 } }],
        "strokeWeight" => 1,
        "strokeAlign" => "CENTER",
        "strokeDashes" => [5, 5]
      }
      styles = {}
      extractor.add_strokes(styles, node)
      expect(styles["border-style"]).to eq("dashed")
    end

    it "ignores invisible strokes" do
      node = {
        "strokes" => [{ "type" => "SOLID", "visible" => false, "color" => { "r" => 0, "g" => 0, "b" => 0, "a" => 1 } }],
        "strokeWeight" => 1
      }
      styles = {}
      extractor.add_strokes(styles, node)
      expect(styles).not_to have_key("border")
    end
  end

  # =============================================
  # add_border_radius
  # =============================================

  describe "#add_border_radius" do
    it "sets uniform corner radius" do
      styles = {}
      extractor.add_border_radius(styles, { "cornerRadius" => 8 })
      expect(styles["border-radius"]).to eq("8px")
    end

    it "sets mixed corner radii from rectangleCornerRadii" do
      styles = {}
      extractor.add_border_radius(styles, { "rectangleCornerRadii" => [4, 8, 12, 16] })
      expect(styles["border-radius"]).to eq("4px 8px 12px 16px")
    end

    it "sets individual corner radii" do
      styles = {}
      node = { "topLeftRadius" => 4, "topRightRadius" => 8, "bottomRightRadius" => 12, "bottomLeftRadius" => 16 }
      extractor.add_border_radius(styles, node)
      expect(styles["border-radius"]).to eq("4px 8px 12px 16px")
    end

    it "ignores zero corner radius" do
      styles = {}
      extractor.add_border_radius(styles, { "cornerRadius" => 0 })
      expect(styles).not_to have_key("border-radius")
    end
  end

  # =============================================
  # add_effects
  # =============================================

  describe "#add_effects" do
    it "generates drop shadow" do
      styles = {}
      effects = [
        {
          "type" => "DROP_SHADOW",
          "offset" => { "x" => 0, "y" => 4 },
          "radius" => 8,
          "spread" => 0,
          "color" => { "r" => 0, "g" => 0, "b" => 0, "a" => 0.25 }
        }
      ]
      extractor.add_effects(styles, effects)
      expect(styles["box-shadow"]).to include("0px 4px 8px 0px")
    end

    it "generates inner shadow with inset" do
      styles = {}
      effects = [
        {
          "type" => "INNER_SHADOW",
          "offset" => { "x" => 0, "y" => 2 },
          "radius" => 4,
          "spread" => 0,
          "color" => { "r" => 0, "g" => 0, "b" => 0, "a" => 0.1 }
        }
      ]
      extractor.add_effects(styles, effects)
      expect(styles["box-shadow"]).to start_with("inset")
    end

    it "generates blur filter" do
      styles = {}
      effects = [{ "type" => "LAYER_BLUR", "radius" => 10 }]
      extractor.add_effects(styles, effects)
      expect(styles["filter"]).to eq("blur(10px)")
    end

    it "generates backdrop blur" do
      styles = {}
      effects = [{ "type" => "BACKGROUND_BLUR", "radius" => 20 }]
      extractor.add_effects(styles, effects)
      expect(styles["backdrop-filter"]).to eq("blur(20px)")
      expect(styles["-webkit-backdrop-filter"]).to eq("blur(20px)")
    end

    it "combines multiple shadows" do
      styles = {}
      effects = [
        { "type" => "DROP_SHADOW", "offset" => { "x" => 0, "y" => 1 }, "radius" => 2, "spread" => 0, "color" => { "r" => 0, "g" => 0, "b" => 0, "a" => 0.1 } },
        { "type" => "DROP_SHADOW", "offset" => { "x" => 0, "y" => 4 }, "radius" => 8, "spread" => 0, "color" => { "r" => 0, "g" => 0, "b" => 0, "a" => 0.2 } }
      ]
      extractor.add_effects(styles, effects)
      expect(styles["box-shadow"]).to include(",") # multiple shadows separated by comma
    end

    it "ignores invisible effects" do
      styles = {}
      effects = [{ "type" => "DROP_SHADOW", "visible" => false }]
      extractor.add_effects(styles, effects)
      expect(styles).not_to have_key("box-shadow")
    end

    it "handles nil effects" do
      styles = {}
      extractor.add_effects(styles, nil)
      expect(styles).to be_empty
    end
  end

  # =============================================
  # generate_css
  # =============================================

  describe "#generate_css" do
    it "generates properly formatted CSS" do
      rules = {
        "root" => { "display" => "flex", "width" => "100px" },
        "child-1" => { "color" => "#000000" }
      }
      css = extractor.generate_css(rules)
      expect(css).to include(".root {")
      expect(css).to include("display: flex;")
      expect(css).to include("width: 100px;")
      expect(css).to include(".child-1 {")
      expect(css).to include("color: #000000;")
    end

    it "returns empty string for no rules" do
      expect(extractor.generate_css({})).to eq("")
    end
  end

  # =============================================
  # to_component_name
  # =============================================

  describe "#to_component_name" do
    it "converts simple names to PascalCase" do
      expect(extractor.to_component_name("my button")).to eq("MyButton")
    end

    it "handles variant-style names (takes first part)" do
      expect(extractor.to_component_name("Size=M, State=default")).to eq("M")
    end

    it "strips special characters" do
      expect(extractor.to_component_name("Button / Primary")).to eq("ButtonPrimary")
    end

    it "strips leading digits" do
      expect(extractor.to_component_name("123-button")).to eq("Button")
    end

    it "returns Component for empty result" do
      expect(extractor.to_component_name("...")).to eq("Component")
    end
  end

  # =============================================
  # vector_frame? / vector_only?
  # =============================================

  describe "#vector_frame?" do
    it "returns true for a frame containing only vectors" do
      node = {
        "type" => "FRAME",
        "children" => [
          { "type" => "VECTOR", "fills" => [] },
          { "type" => "ELLIPSE", "fills" => [] }
        ]
      }
      expect(extractor.vector_frame?(node)).to be true
    end

    it "returns false for a frame with text children" do
      node = {
        "type" => "FRAME",
        "children" => [
          { "type" => "VECTOR" },
          { "type" => "TEXT" }
        ]
      }
      expect(extractor.vector_frame?(node)).to be false
    end

    it "returns false for an empty frame" do
      node = { "type" => "FRAME", "children" => [] }
      expect(extractor.vector_frame?(node)).to be false
    end

    it "returns false for non-container types" do
      node = { "type" => "TEXT" }
      expect(extractor.vector_frame?(node)).to be false
    end
  end

  describe "#vector_only?" do
    it "returns true for VECTOR types" do
      Figma::StyleExtractor::VECTOR_TYPES.each do |type|
        expect(extractor.vector_only?({ "type" => type })).to be true
      end
    end

    it "returns false for nodes with IMAGE fills" do
      node = {
        "type" => "RECTANGLE",
        "fills" => [{ "type" => "IMAGE" }]
      }
      expect(extractor.vector_only?(node)).to be false
    end

    it "returns true for nested vector-only containers" do
      node = {
        "type" => "GROUP",
        "children" => [
          { "type" => "VECTOR", "fills" => [] },
          { "type" => "FRAME", "children" => [{ "type" => "ELLIPSE", "fills" => [] }] }
        ]
      }
      expect(extractor.vector_only?(node)).to be true
    end
  end

  # =============================================
  # normalize_icon_name
  # =============================================

  describe "#normalize_icon_name" do
    it "downcases and slugifies" do
      expect(extractor.normalize_icon_name("Icon Arrow Right")).to eq("icon-arrow-right")
    end

    it "strips special characters" do
      expect(extractor.normalize_icon_name("Icon/Arrow.Right!")).to eq("iconarrowright")
    end

    it "collapses multiple dashes" do
      expect(extractor.normalize_icon_name("icon  --  name")).to eq("icon-name")
    end
  end

  # =============================================
  # Gradient generation
  # =============================================

  describe "#generate_linear_gradient" do
    it "produces correct angle and stops" do
      fill = {
        "gradientHandlePositions" => [
          { "x" => 0, "y" => 0.5 },
          { "x" => 1, "y" => 0.5 }
        ],
        "gradientStops" => [
          { "color" => { "r" => 1, "g" => 0, "b" => 0, "a" => 1 }, "position" => 0 },
          { "color" => { "r" => 0, "g" => 0, "b" => 1, "a" => 1 }, "position" => 1 }
        ]
      }
      result = extractor.generate_linear_gradient(fill)
      expect(result).to match(/linear-gradient\(90deg/)
      expect(result).to include("#ff0000 0%")
      expect(result).to include("#0000ff 100%")
    end

    it "falls back when no handle positions" do
      fill = {}
      result = extractor.generate_linear_gradient(fill)
      expect(result).to include("180deg")
    end
  end

  describe "#generate_radial_gradient" do
    it "produces radial gradient with stops" do
      fill = {
        "gradientStops" => [
          { "color" => { "r" => 1, "g" => 1, "b" => 1, "a" => 1 }, "position" => 0 },
          { "color" => { "r" => 0, "g" => 0, "b" => 0, "a" => 1 }, "position" => 1 }
        ]
      }
      result = extractor.generate_radial_gradient(fill)
      expect(result).to match(/radial-gradient\(ellipse at center/)
    end
  end
end
