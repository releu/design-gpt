import { mount } from "@vue/test-utils";
import AIEngineSelector from "./AIEngineSelector.vue";

describe("AIEngineSelector", () => {
  it("displays the ai engine label", () => {
    const wrapper = mount(AIEngineSelector);
    expect(wrapper.find(".AIEngineSelector__label").text()).toBe("ai engine");
  });

  it("displays the model name", () => {
    const wrapper = mount(AIEngineSelector);
    expect(wrapper.find(".AIEngineSelector__model").text()).toBe("ChatGPT");
  });

  it("emits generate when generate button is clicked", async () => {
    const wrapper = mount(AIEngineSelector);
    await wrapper.find(".AIEngineSelector__generate").trigger("click");
    expect(wrapper.emitted("generate")).toHaveLength(1);
  });

  it("displays the subtitle", () => {
    const wrapper = mount(AIEngineSelector);
    expect(wrapper.find(".AIEngineSelector__subtitle").text()).toBe(
      "don't share nda for now",
    );
  });
});
