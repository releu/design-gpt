import { mount } from "@vue/test-utils";
import FigmaUrlInput from "./FigmaUrlInput.vue";

describe("FigmaUrlInput", () => {
  it("renders input and button", () => {
    const wrapper = mount(FigmaUrlInput);
    expect(wrapper.find(".FigmaUrlInput__input").exists()).toBe(true);
    expect(wrapper.find(".FigmaUrlInput__button").exists()).toBe(true);
  });

  it("disables button when URL is invalid", () => {
    const wrapper = mount(FigmaUrlInput, {
      props: { modelValue: "not a url" },
    });
    expect(
      wrapper.find(".FigmaUrlInput__button").classes(),
    ).toContain("FigmaUrlInput__button_disabled");
  });

  it("enables button when URL contains figma.com", () => {
    const wrapper = mount(FigmaUrlInput, {
      props: { modelValue: "https://figma.com/design/abc123/test" },
    });
    expect(
      wrapper.find(".FigmaUrlInput__button").classes(),
    ).not.toContain("FigmaUrlInput__button_disabled");
  });

  it("emits import on button click with valid URL", async () => {
    const wrapper = mount(FigmaUrlInput, {
      props: { modelValue: "https://figma.com/design/abc123/test" },
    });
    await wrapper.find(".FigmaUrlInput__button").trigger("click");
    expect(wrapper.emitted("import")).toEqual([
      ["https://figma.com/design/abc123/test"],
    ]);
  });

  it("shows error message when provided", () => {
    const wrapper = mount(FigmaUrlInput, {
      props: { error: "Something went wrong" },
    });
    expect(wrapper.find(".FigmaUrlInput__error").text()).toBe(
      "Something went wrong",
    );
  });

  it("shows importing text when importing", () => {
    const wrapper = mount(FigmaUrlInput, {
      props: { importing: true, modelValue: "https://figma.com/design/x/y" },
    });
    expect(wrapper.find(".FigmaUrlInput__button").text()).toBe("Importing...");
  });
});
