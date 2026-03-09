import { mount } from "@vue/test-utils";
import Layout from "./Layout.vue";
import Header from "./Header.vue";

describe("Layout", () => {
  it("renders the grid layout", () => {
    const wrapper = mount(Layout, {
      global: { components: { Header } },
    });
    expect(wrapper.find(".Layout").exists()).toBe(true);
  });

  it("renders named slots", () => {
    const wrapper = mount(Layout, {
      global: { components: { Header } },
      slots: {
        "top-bar-left": "<div>Logo</div>",
        "top-bar-right": "<div>Buttons</div>",
        prompt: "<div>Prompt Area</div>",
        "design-system": "<div>DS Area</div>",
        preview: "<div>Preview Area</div>",
        "ai-engine": "<div>AI Engine</div>",
      },
    });
    expect(wrapper.find(".Header__group_left").text()).toContain("Logo");
    expect(wrapper.find(".Header__group_right").text()).toContain("Buttons");
    expect(wrapper.find(".Layout__prompt").text()).toBe("Prompt Area");
    expect(wrapper.find(".Layout__design-system").text()).toBe("DS Area");
    expect(wrapper.find(".Layout__preview").text()).toBe("Preview Area");
  });
});
