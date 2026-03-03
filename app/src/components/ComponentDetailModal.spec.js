import { mount } from "@vue/test-utils";
import ComponentDetailModal from "./ComponentDetailModal.vue";

describe("ComponentDetailModal", () => {
  const component = {
    id: "42",
    name: "Button",
    status: "imported",
    has_html: true,
    match_percent: 95.5,
    has_figma_screenshot: true,
    has_react_screenshot: true,
    has_diff: true,
  };

  it("renders component name", () => {
    const wrapper = mount(ComponentDetailModal, {
      props: { component },
    });
    expect(wrapper.find(".ComponentDetailModal__title").text()).toBe("Button");
  });

  it("renders match percent", () => {
    const wrapper = mount(ComponentDetailModal, {
      props: { component },
    });
    expect(wrapper.find(".ComponentDetailModal__match").text()).toBe(
      "95.5% match",
    );
  });

  it("renders preview iframe", () => {
    const wrapper = mount(ComponentDetailModal, {
      props: { component },
    });
    const iframe = wrapper.find(".ComponentDetailModal__iframe");
    expect(iframe.exists()).toBe(true);
    expect(iframe.attributes("src")).toBe("/api/components/42/html_preview");
  });

  it("emits close on backdrop click", async () => {
    const wrapper = mount(ComponentDetailModal, {
      props: { component },
    });
    await wrapper.find(".ComponentDetailModal").trigger("click");
    expect(wrapper.emitted("close")).toBeTruthy();
  });

  it("emits close on close button click", async () => {
    const wrapper = mount(ComponentDetailModal, {
      props: { component },
    });
    await wrapper.find(".ComponentDetailModal__close").trigger("click");
    expect(wrapper.emitted("close")).toBeTruthy();
  });

  it("emits reimport on update button click", async () => {
    const wrapper = mount(ComponentDetailModal, {
      props: { component },
    });
    await wrapper.find(".ComponentDetailModal__btn_update").trigger("click");
    expect(wrapper.emitted("reimport")).toEqual([[component]]);
  });

  it("shows error message when present", () => {
    const wrapper = mount(ComponentDetailModal, {
      props: {
        component: { ...component, error_message: "Something broke" },
      },
    });
    expect(wrapper.find(".ComponentDetailModal__error").text()).toBe(
      "Something broke",
    );
  });
});
