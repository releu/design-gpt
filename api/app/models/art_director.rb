class ArtDirector
  include ComponentNaming

  def initialize(design)
    @design = design
    @render = design.iterations.last.render
    @libraries = design.component_libraries
  end

  def analyze
    design_concept_parts = [
      { type: "input_text", text: "Here are the style references to follow:" }
    ]

    %w[
      https://deadsimple.fra1.digitaloceanspaces.com/o/af9ff9d9.png
      https://deadsimple.fra1.digitaloceanspaces.com/o/f766e85d.png
      https://deadsimple.fra1.digitaloceanspaces.com/o/9921f811.png
      https://deadsimple.fra1.digitaloceanspaces.com/o/00b586f1.png
      https://deadsimple.fra1.digitaloceanspaces.com/o/ece4da1c.png
      https://deadsimple.fra1.digitaloceanspaces.com/o/30de9525.png
      https://deadsimple.fra1.digitaloceanspaces.com/o/c9bea5e8.png
      https://deadsimple.fra1.digitaloceanspaces.com/o/0b8c768f.png
      https://deadsimple.fra1.digitaloceanspaces.com/o/7d644074.png
      https://deadsimple.fra1.digitaloceanspaces.com/o/d813321a.png
      https://deadsimple.fra1.digitaloceanspaces.com/o/90b106e4.png
    ].each do |url|
      design_concept_parts << { type: "input_image", image_url: url }
    end

    about_components = "Here are the available components:\n\n"
    component_descriptions.each do |name, desc|
      about_components << "#{name}: #{desc}\n---\n"
    end

    AiTask.create! do |t|
      t.payload = {
        model: "gpt-5",
        input: [
          {
            role: "system",
            content: [
              {
                type: "input_text",
                text: <<~SYS.squish
                  You are an art director at a tech company. Ensure the design follows the style
                  and spirit of the references. Designers send mockups. Your job is to decide
                  "ok" or "shit" and give short, specific feedback. Write exactly what to fix in
                  the code or what to add. Only request things possible with the available
                  components. Think about what can be done with available capabilities.
                  Response format strictly follows the schema (verdict + feedback).
                  Use line breaks in feedback for readability.
                SYS
              }
            ]
          },
          { role: "user", content: design_concept_parts },
          { role: "user", content: about_components },
          {
            role: "user",
            content: [
              { type: "input_text", text: "Here's what I made. What do you think?" },
              { type: "input_image", image_url: "https://jan-designer.xyz/api/renders/#{@render.token}" }
            ]
          }
        ],
        text: {
          format: {
            type: "json_schema",
            name: "design_review",
            strict: true,
            schema: {
              type: "object",
              additionalProperties: false,
              required: ["verdict", "feedback"],
              properties: {
                verdict: { type: "string", enum: ["ok", "shit"] },
                feedback: { type: "string" }
              }
            }
          }
        }
      }
    end
  end

  private

  def component_descriptions
    return {} unless @libraries.any?

    result = {}
    @libraries.each do |lib|
      lib.component_sets.each do |cs|
        name = to_component_name(cs.name)
        result[name] = cs.description.presence || "Component"
      end
      lib.components.where(enabled: true).each do |comp|
        name = to_component_name(comp.name)
        result[name] = comp.description.presence || "Component"
      end
    end
    result
  end
end
