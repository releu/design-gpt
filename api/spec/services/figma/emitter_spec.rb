require "rails_helper"

RSpec.describe Figma::Emitter do
  let(:emitter) { described_class.new("TestComponent") }

  describe "#emit_node" do
    it "emits frame with children" do
      ir = Figma::IR.frame(node_id: "1", name: "wrapper", styles: { "display" => "flex" },
                           children: [
                             Figma::IR.text(node_id: "2", name: "label", styles: {}, text_content: "Hi")
                           ])
      jsx = emitter.emit_node(ir, 0, is_root: true)
      expect(jsx).to include('className=')
      expect(jsx).to include('Hi')
    end

    it "emits text with static content" do
      ir = Figma::IR.text(node_id: "1", name: "label", styles: { "font-size" => "14px" },
                          text_content: "Hello World")
      jsx = emitter.emit_node(ir)
      expect(jsx).to include("<span")
      expect(jsx).to include("Hello World")
    end

    it "emits text with prop binding" do
      ir = Figma::IR.text(node_id: "1", name: "label", styles: {},
                          text_prop: "title")
      jsx = emitter.emit_node(ir)
      expect(jsx).to include("{title}")
    end

    it "emits component_ref" do
      ir = Figma::IR.component_ref(node_id: "1", name: "btn", component_name: "Button",
                                    prop_overrides: { "label" => '"Save"' })
      jsx = emitter.emit_node(ir)
      expect(jsx).to include("<Button")
      expect(jsx).to include('label="Save"')
    end

    it "emits component_ref without props" do
      ir = Figma::IR.component_ref(node_id: "1", name: "btn", component_name: "Icon")
      jsx = emitter.emit_node(ir)
      expect(jsx).to include("<Icon />")
    end

    it "emits slot as props expression" do
      ir = Figma::IR.slot(node_id: "1", name: "content", prop_name: "content")
      jsx = emitter.emit_node(ir)
      expect(jsx).to include("{props.content}")
    end

    it "emits icon_swap with style overrides wrapped in a styled span" do
      ir = Figma::IR.icon_swap(node_id: "1", name: "icon", prop_name: "IconComponent",
                                style_overrides: { "color" => "#ffffff", "width" => "20px", "height" => "20px" })
      jsx = emitter.emit_node(ir)
      # Icon must be wrapped in a <span> with style, not receive style as a prop.
      # This ensures color works for both SVG components (which spread props)
      # and regular multi-variant components (which do not spread props).
      expect(jsx).to include("<span style=")
      expect(jsx).to include("color: \"#ffffff\"")
      expect(jsx).to include("<IconComponent />")
      expect(jsx).to include("</span>")
    end

    it "emits icon_swap without style overrides" do
      ir = Figma::IR.icon_swap(node_id: "1", name: "icon", prop_name: "IconComponent",
                                style_overrides: {})
      jsx = emitter.emit_node(ir)
      expect(jsx).to include("{IconComponent && <IconComponent />}")
    end

    it "emits image_swap" do
      ir = Figma::IR.image_swap(node_id: "1", name: "hero", prop_name: "heroImage",
                                 styles: { "width" => "100px" })
      jsx = emitter.emit_node(ir)
      expect(jsx).to include("backgroundImage")
      expect(jsx).to include("heroImage")
    end

    it "emits visibility-gated node" do
      ir = Figma::IR.frame(node_id: "1", name: "header", styles: {}, children: [],
                           visibility_prop: "showHeader")
      jsx = emitter.emit_node(ir)
      expect(jsx).to include("{showHeader && (")
    end

    it "emits unresolved as pink placeholder" do
      ir = Figma::IR.unresolved(node_id: "1", name: "x", styles: { "background" => "#FF69B4" },
                                 instance_name: "MissingIcon")
      jsx = emitter.emit_node(ir)
      expect(jsx).to include("Missing: MissingIcon")
    end

    it "emits svg_inline" do
      ir = Figma::IR.svg_inline(node_id: "1", name: "icon", styles: {},
                                 svg_content: '<svg><path d="M0 0"/></svg>')
      jsx = emitter.emit_node(ir)
      expect(jsx).to include("dangerouslySetInnerHTML")
    end

    it "emits png_inline" do
      ir = Figma::IR.png_inline(node_id: "1", name: "image", styles: {},
                                 png_data: "iVBORw0KGgo=")
      jsx = emitter.emit_node(ir)
      expect(jsx).to include("data:image/png;base64,")
    end

    it "emits empty frame as self-closing div" do
      ir = Figma::IR.frame(node_id: "1", name: "spacer", styles: { "width" => "10px" },
                           children: [])
      jsx = emitter.emit_node(ir, 0, is_root: false)
      expect(jsx).to include("/>")
    end

    it "returns empty string for nil" do
      expect(emitter.emit_node(nil)).to eq("")
    end
  end

  describe "#css_rules" do
    it "collects CSS rules from emitted nodes" do
      ir = Figma::IR.frame(node_id: "1", name: "box", styles: { "display" => "flex" },
                           children: [])
      emitter.emit_node(ir, 0, is_root: true)
      expect(emitter.css_rules).to have_key("root")
      expect(emitter.css_rules["root"]).to include("display" => "flex")
    end
  end
end
