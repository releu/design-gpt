import { mount } from "@vue/test-utils";
import MainLayout from "./MainLayout.vue";

describe("MainLayout", () => {
  it("renders the grid layout", () => {
    const wrapper = mount(MainLayout);
    expect(wrapper.find(".MainLayout").exists()).toBe(true);
  });

  it("renders named slots", () => {
    const wrapper = mount(MainLayout, {
      slots: {
        "top-bar-left": "<div>Logo</div>",
        "top-bar-right": "<div>Buttons</div>",
        prompt: "<div>Prompt Area</div>",
        "design-system": "<div>DS Area</div>",
        preview: "<div>Preview Area</div>",
        "ai-engine": "<div>AI Engine</div>",
      },
    });
    expect(wrapper.find(".MainLayout__top-bar-left").text()).toBe("Logo");
    expect(wrapper.find(".MainLayout__top-bar-right").text()).toBe("Buttons");
    expect(wrapper.find(".MainLayout__prompt").text()).toBe("Prompt Area");
    expect(wrapper.find(".MainLayout__design-system").text()).toBe("DS Area");
    expect(wrapper.find(".MainLayout__preview").text()).toBe("Preview Area");
    expect(wrapper.find(".MainLayout__ai-engine").text()).toBe("AI Engine");
  });
});
