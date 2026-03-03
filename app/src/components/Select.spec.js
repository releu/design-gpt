import { mount } from "@vue/test-utils";
import Select from "./Select.vue";

describe("Select", () => {
  const values = [
    { id: "1", name: "Option A" },
    { id: "2", name: "Option B" },
  ];

  it("displays the selected option name", () => {
    const wrapper = mount(Select, {
      props: { modelValue: "2", values },
    });
    expect(wrapper.find(".Select__value-text").text()).toBe("Option B");
  });

  it("shows empty string when no option matches", () => {
    const wrapper = mount(Select, {
      props: { modelValue: "999", values },
    });
    expect(wrapper.find(".Select__value-text").text()).toBe("");
  });

  it("renders all options in the select element", () => {
    const wrapper = mount(Select, {
      props: { modelValue: "1", values },
    });
    const options = wrapper.findAll("option");
    expect(options).toHaveLength(2);
    expect(options[0].text()).toBe("Option A");
    expect(options[1].text()).toBe("Option B");
  });

  it("emits update:modelValue on change", async () => {
    const wrapper = mount(Select, {
      props: { modelValue: "1", values },
    });
    await wrapper.find("select").setValue("2");
    expect(wrapper.emitted("update:modelValue")[0]).toEqual(["2"]);
  });
});
