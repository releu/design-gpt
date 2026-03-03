import { mount } from "@vue/test-utils";
import VisualDiffOverlay from "./VisualDiffOverlay.vue";

describe("VisualDiffOverlay", () => {
  it("renders figma and react panels", () => {
    const wrapper = mount(VisualDiffOverlay, {
      props: {
        figmaUrl: "/screenshots/figma.png",
        reactUrl: "/screenshots/react.png",
      },
    });
    const panels = wrapper.findAll(".VisualDiffOverlay__panel");
    expect(panels).toHaveLength(2);
  });

  it("renders diff panel when diffUrl provided", () => {
    const wrapper = mount(VisualDiffOverlay, {
      props: {
        figmaUrl: "/figma.png",
        reactUrl: "/react.png",
        diffUrl: "/diff.png",
      },
    });
    const panels = wrapper.findAll(".VisualDiffOverlay__panel");
    expect(panels).toHaveLength(3);
  });

  it("shows match percent with high class", () => {
    const wrapper = mount(VisualDiffOverlay, {
      props: { matchPercent: 97 },
    });
    expect(wrapper.find(".VisualDiffOverlay__score").text()).toBe("97% match");
    expect(wrapper.find(".VisualDiffOverlay__score").classes()).toContain(
      "VisualDiffOverlay__score_high",
    );
  });

  it("shows match percent with low class", () => {
    const wrapper = mount(VisualDiffOverlay, {
      props: { matchPercent: 65 },
    });
    expect(wrapper.find(".VisualDiffOverlay__score").classes()).toContain(
      "VisualDiffOverlay__score_low",
    );
  });

  it("shows placeholder when no URLs provided", () => {
    const wrapper = mount(VisualDiffOverlay);
    const placeholders = wrapper.findAll(".VisualDiffOverlay__placeholder");
    expect(placeholders).toHaveLength(2);
  });
});
