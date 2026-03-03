import { mount } from "@vue/test-utils";
import Loader from "./Loader.vue";

describe("Loader", () => {
  it("renders the animation element", () => {
    const wrapper = mount(Loader);
    expect(wrapper.find(".Loader__animation").exists()).toBe(true);
  });
});
