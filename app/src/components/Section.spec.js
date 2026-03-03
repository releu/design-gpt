import { mount } from "@vue/test-utils";
import Section from "./Section.vue";

describe("Section", () => {
  it("renders slot content", () => {
    const wrapper = mount(Section, {
      slots: { default: "<p>Section content</p>" },
    });
    expect(wrapper.text()).toContain("Section content");
  });

  it("has the Section class", () => {
    const wrapper = mount(Section);
    expect(wrapper.find(".Section").exists()).toBe(true);
  });
});
