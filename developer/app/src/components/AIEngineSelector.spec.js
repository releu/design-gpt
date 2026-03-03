import { mount } from "@vue/test-utils";
import AIEngineSelector from "./AIEngineSelector.vue";

describe("AIEngineSelector", () => {
  it("displays the AI ENGINE label", () => {
    const wrapper = mount(AIEngineSelector);
    expect(wrapper.find(".AIEngineSelector__label").text()).toBe("AI ENGINE");
  });

  it("displays the model name", () => {
    const wrapper = mount(AIEngineSelector);
    expect(wrapper.find(".AIEngineSelector__model").text()).toBe("Qwen 325B");
  });

  it("emits generate when Generate button is clicked", async () => {
    const wrapper = mount(AIEngineSelector);
    await wrapper.find(".AIEngineSelector__generate").trigger("click");
    expect(wrapper.emitted("generate")).toHaveLength(1);
  });

  it("renders the NDA toggle", () => {
    const wrapper = mount(AIEngineSelector);
    expect(wrapper.find(".AIEngineSelector__toggle-text").text()).toBe("NDA");
  });
});
