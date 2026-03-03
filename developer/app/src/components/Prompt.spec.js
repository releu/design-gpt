import { mount } from "@vue/test-utils";
import Prompt from "./Prompt.vue";

describe("Prompt", () => {
  it("renders the label", () => {
    const wrapper = mount(Prompt, {
      props: { modelValue: "" },
    });
    expect(wrapper.find(".Prompt__label").text()).toBe("prompt");
  });

  it("displays the modelValue in the textarea", () => {
    const wrapper = mount(Prompt, {
      props: { modelValue: "Design a login page" },
    });
    expect(wrapper.find("textarea").element.value).toBe("Design a login page");
  });

  it("emits update:modelValue on input", async () => {
    const wrapper = mount(Prompt, {
      props: { modelValue: "" },
    });
    await wrapper.find("textarea").setValue("New prompt");
    expect(wrapper.emitted("update:modelValue")[0]).toEqual(["New prompt"]);
  });

  it("has a placeholder", () => {
    const wrapper = mount(Prompt, {
      props: { modelValue: "" },
    });
    expect(wrapper.find("textarea").attributes("placeholder")).toBe(
      "describe what you want to create",
    );
  });
});
