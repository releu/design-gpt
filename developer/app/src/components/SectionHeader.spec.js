import { mount } from "@vue/test-utils";
import SectionHeader from "./SectionHeader.vue";

describe("SectionHeader", () => {
  it("renders items as tabs", () => {
    const wrapper = mount(SectionHeader, {
      props: { items: ["Code", "Preview", "Chat"] },
    });
    const tabs = wrapper.findAll(".SectionHeader__item");
    expect(tabs).toHaveLength(3);
    expect(tabs[0].text()).toBe("Code");
    expect(tabs[1].text()).toBe("Preview");
  });

  it("marks the first item as active by default", () => {
    const wrapper = mount(SectionHeader, {
      props: { items: ["Code", "Preview"] },
    });
    const tabs = wrapper.findAll(".SectionHeader__item");
    expect(tabs[0].classes()).toContain("SectionHeader__item_active");
    expect(tabs[1].classes()).not.toContain("SectionHeader__item_active");
  });

  it("switches active item on click", async () => {
    const wrapper = mount(SectionHeader, {
      props: { items: ["Code", "Preview"] },
    });
    const tabs = wrapper.findAll(".SectionHeader__item");
    await tabs[1].trigger("click");
    expect(tabs[1].classes()).toContain("SectionHeader__item_active");
    expect(tabs[0].classes()).not.toContain("SectionHeader__item_active");
  });

  it("renders default slot when items is empty", () => {
    const wrapper = mount(SectionHeader, {
      props: { items: [] },
      slots: { default: "<span>Custom header</span>" },
    });
    expect(wrapper.text()).toContain("Custom header");
  });

  it("shows the correct slot content based on active tab", async () => {
    const wrapper = mount(SectionHeader, {
      props: { items: ["Tab A", "Tab B"] },
      slots: {
        "item-0": "<div>Content A</div>",
        "item-1": "<div>Content B</div>",
      },
    });
    expect(wrapper.text()).toContain("Content A");
    expect(wrapper.text()).not.toContain("Content B");

    const tabs = wrapper.findAll(".SectionHeader__item");
    await tabs[1].trigger("click");
    expect(wrapper.text()).toContain("Content B");
    expect(wrapper.text()).not.toContain("Content A");
  });
});
