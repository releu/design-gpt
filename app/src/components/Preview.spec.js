import { mount } from "@vue/test-utils";
import Preview from "./Preview.vue";

describe("Preview", () => {
  it("renders with the correct layout class", () => {
    const wrapper = mount(Preview, {
      props: { layout: "mobile", renderer: "about:blank" },
    });
    expect(wrapper.classes()).toContain("Preview_mobile");
  });

  it("switches layout class based on prop", () => {
    const wrapper = mount(Preview, {
      props: { layout: "desktop", renderer: "about:blank" },
    });
    expect(wrapper.classes()).toContain("Preview_desktop");
  });

  it("renders an iframe with the renderer src", () => {
    const wrapper = mount(Preview, {
      props: { renderer: "https://example.com", layout: "desktop" },
    });
    expect(wrapper.find("iframe").attributes("src")).toBe(
      "https://example.com",
    );
  });
});
