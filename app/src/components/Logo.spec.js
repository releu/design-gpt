import { mount } from "@vue/test-utils";
import Logo from "./Logo.vue";

describe("Logo", () => {
  it("renders with the Logo class", () => {
    const wrapper = mount(Logo);
    expect(wrapper.find(".Logo").exists()).toBe(true);
  });
});
