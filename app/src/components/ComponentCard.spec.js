import { mount } from "@vue/test-utils";
import ComponentCard from "./ComponentCard.vue";

describe("ComponentCard", () => {
  const component = {
    id: "42",
    name: "Button",
    status: "imported",
    has_html: true,
    match_percent: 95.5,
  };

  it("renders component name", () => {
    const wrapper = mount(ComponentCard, {
      props: { component },
    });
    expect(wrapper.find(".ComponentCard__name").text()).toBe("Button");
  });

  it("renders match percent", () => {
    const wrapper = mount(ComponentCard, {
      props: { component },
    });
    expect(wrapper.find(".ComponentCard__match").text()).toBe("95.5%");
  });

  it("renders preview iframe when has_html is true", () => {
    const wrapper = mount(ComponentCard, {
      props: { component },
    });
    const iframe = wrapper.find(".ComponentCard__iframe");
    expect(iframe.exists()).toBe(true);
    expect(iframe.attributes("src")).toBe("/api/components/42/html_preview");
  });

  it("shows placeholder when no html", () => {
    const wrapper = mount(ComponentCard, {
      props: { component: { ...component, has_html: false } },
    });
    expect(wrapper.find(".ComponentCard__placeholder").exists()).toBe(true);
  });

  it("emits select on click", async () => {
    const wrapper = mount(ComponentCard, {
      props: { component },
    });
    await wrapper.trigger("click");
    expect(wrapper.emitted("select")).toEqual([[component]]);
  });
});
