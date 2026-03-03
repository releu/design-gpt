import { mount } from "@vue/test-utils";
import Menu from "./Menu.vue";

describe("Menu", () => {
  it("renders menu items", () => {
    const wrapper = mount(Menu, {
      props: {
        items: [
          { name: "Home", route: "/" },
          { name: "Settings", route: "/settings" },
        ],
      },
      global: {
        stubs: { RouterLink: { template: "<a><slot /></a>", props: ["to"] } },
      },
    });
    const items = wrapper.findAll(".Menu__item-text");
    expect(items).toHaveLength(2);
    expect(items[0].text()).toBe("Home");
    expect(items[1].text()).toBe("Settings");
  });

  it("renders empty when no items", () => {
    const wrapper = mount(Menu, {
      props: { items: [] },
      global: {
        stubs: { RouterLink: { template: "<a><slot /></a>", props: ["to"] } },
      },
    });
    expect(wrapper.findAll(".Menu__item")).toHaveLength(0);
  });
});
