import { mount } from "@vue/test-utils";
import ProgressBar from "./ProgressBar.vue";

describe("ProgressBar", () => {
  it("renders with correct fill width", () => {
    const wrapper = mount(ProgressBar, {
      props: { value: 50, max: 100 },
    });
    const fill = wrapper.find(".ProgressBar__fill");
    expect(fill.attributes("style")).toContain("width: 50%");
  });

  it("clamps fill width to 100%", () => {
    const wrapper = mount(ProgressBar, {
      props: { value: 150, max: 100 },
    });
    const fill = wrapper.find(".ProgressBar__fill");
    expect(fill.attributes("style")).toContain("width: 100%");
  });

  it("handles zero max gracefully", () => {
    const wrapper = mount(ProgressBar, {
      props: { value: 50, max: 0 },
    });
    const fill = wrapper.find(".ProgressBar__fill");
    expect(fill.attributes("style")).toContain("width: 0%");
  });

  it("renders label when provided", () => {
    const wrapper = mount(ProgressBar, {
      props: { value: 2, max: 4, label: "Step 2 of 4" },
    });
    expect(wrapper.find(".ProgressBar__label").text()).toBe("Step 2 of 4");
  });

  it("hides label when not provided", () => {
    const wrapper = mount(ProgressBar, {
      props: { value: 50, max: 100 },
    });
    expect(wrapper.find(".ProgressBar__label").exists()).toBe(false);
  });
});
