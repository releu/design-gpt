import { mount } from "@vue/test-utils";
import Snippet from "./Snippet.vue";

describe("Snippet", () => {
  it("renders slot content", () => {
    const wrapper = mount(Snippet, {
      slots: { default: "const x = 42;" },
    });
    expect(wrapper.text()).toContain("const x = 42;");
  });

  it("has the Snippet class", () => {
    const wrapper = mount(Snippet);
    expect(wrapper.find(".Snippet").exists()).toBe(true);
  });
});
