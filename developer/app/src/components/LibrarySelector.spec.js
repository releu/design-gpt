import { mount } from "@vue/test-utils";
import LibrarySelector from "./LibrarySelector.vue";

describe("LibrarySelector", () => {
  it("renders libraries from props", () => {
    const wrapper = mount(LibrarySelector, {
      props: {
        libraries: [
          { id: "1", name: "Cubes" },
          { id: "2", name: "Gravity UI" },
        ],
      },
    });
    const items = wrapper.findAll(".LibrarySelector__item-name");
    expect(items).toHaveLength(2);
    expect(items[0].text()).toBe("Cubes");
    expect(items[1].text()).toBe("Gravity UI");
  });

  it("filters out items with id 'import'", () => {
    const wrapper = mount(LibrarySelector, {
      props: {
        libraries: [
          { id: "1", name: "Cubes" },
          { id: "import", name: "Import" },
        ],
      },
    });
    const items = wrapper.findAll(".LibrarySelector__item-name");
    expect(items).toHaveLength(1);
    expect(items[0].text()).toBe("Cubes");
  });

  it("handles empty libraries prop", () => {
    const wrapper = mount(LibrarySelector, {
      props: { libraries: [] },
    });
    expect(wrapper.findAll(".LibrarySelector__item")).toHaveLength(0);
  });

  it("handles undefined libraries prop", () => {
    const wrapper = mount(LibrarySelector);
    expect(wrapper.findAll(".LibrarySelector__item")).toHaveLength(0);
  });

  it("shows the New design system button", () => {
    const wrapper = mount(LibrarySelector);
    expect(wrapper.find(".LibrarySelector__new-ds").text()).toBe(
      "New design system",
    );
  });
});
