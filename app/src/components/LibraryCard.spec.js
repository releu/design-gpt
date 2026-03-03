import { mount } from "@vue/test-utils";
import LibraryCard from "./LibraryCard.vue";

describe("LibraryCard", () => {
  const library = {
    id: "1",
    name: "My Library",
    status: "ready",
    components_count: 12,
    figma_file_name: "my-file",
  };

  it("renders library name", () => {
    const wrapper = mount(LibraryCard, {
      props: { library },
    });
    expect(wrapper.find(".LibraryCard__name").text()).toBe("My Library");
  });

  it("renders component count", () => {
    const wrapper = mount(LibraryCard, {
      props: { library },
    });
    expect(wrapper.find(".LibraryCard__count").text()).toBe("12 components");
  });

  it("renders figma file name", () => {
    const wrapper = mount(LibraryCard, {
      props: { library },
    });
    expect(wrapper.find(".LibraryCard__source").text()).toBe("my-file");
  });

  it("applies selected class when selected", () => {
    const wrapper = mount(LibraryCard, {
      props: { library, selected: true },
    });
    expect(wrapper.find(".LibraryCard").classes()).toContain(
      "LibraryCard_selected",
    );
  });

  it("emits select on click", async () => {
    const wrapper = mount(LibraryCard, {
      props: { library },
    });
    await wrapper.trigger("click");
    expect(wrapper.emitted("select")).toEqual([[library]]);
  });
});
