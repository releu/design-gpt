import { mount } from "@vue/test-utils";
import ModuleContentDesignSystem from "./ModuleContentDesignSystem.vue";

describe("ModuleContentDesignSystem", () => {
  it("renders libraries from props", () => {
    const wrapper = mount(ModuleContentDesignSystem, {
      props: {
        libraries: [
          { id: "1", name: "Cubes" },
          { id: "2", name: "Gravity UI" },
        ],
      },
    });
    const items = wrapper.findAll(".ModuleContentDesignSystem__item-name");
    expect(items).toHaveLength(2);
    expect(items[0].text()).toBe("Cubes");
    expect(items[1].text()).toBe("Gravity UI");
  });

  it("filters out items with id 'import'", () => {
    const wrapper = mount(ModuleContentDesignSystem, {
      props: {
        libraries: [
          { id: "1", name: "Cubes" },
          { id: "import", name: "Import" },
        ],
      },
    });
    const items = wrapper.findAll(".ModuleContentDesignSystem__item-name");
    expect(items).toHaveLength(1);
    expect(items[0].text()).toBe("Cubes");
  });

  it("handles empty libraries prop", () => {
    const wrapper = mount(ModuleContentDesignSystem, {
      props: { libraries: [] },
    });
    expect(wrapper.findAll(".ModuleContentDesignSystem__item")).toHaveLength(0);
  });

  it("handles undefined libraries prop", () => {
    const wrapper = mount(ModuleContentDesignSystem);
    expect(wrapper.findAll(".ModuleContentDesignSystem__item")).toHaveLength(0);
  });

  it("shows the new button", () => {
    const wrapper = mount(ModuleContentDesignSystem);
    expect(wrapper.find(".ModuleContentDesignSystem__new-ds").text()).toBe("new");
  });
});
