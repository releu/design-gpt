import { mount } from "@vue/test-utils";
import ComponentStatusBadge from "./ComponentStatusBadge.vue";

describe("ComponentStatusBadge", () => {
  it("renders 'Pending' for pending status", () => {
    const wrapper = mount(ComponentStatusBadge, {
      props: { status: "pending" },
    });
    expect(wrapper.text()).toBe("Pending");
    expect(wrapper.classes()).toContain("ComponentStatusBadge_pending");
  });

  it("renders 'Imported' for imported status", () => {
    const wrapper = mount(ComponentStatusBadge, {
      props: { status: "imported" },
    });
    expect(wrapper.text()).toBe("Imported");
    expect(wrapper.classes()).toContain("ComponentStatusBadge_imported");
  });

  it("renders 'Error' for error status", () => {
    const wrapper = mount(ComponentStatusBadge, {
      props: { status: "error" },
    });
    expect(wrapper.text()).toBe("Error");
    expect(wrapper.classes()).toContain("ComponentStatusBadge_error");
  });

  it("renders 'Ready' for ready status", () => {
    const wrapper = mount(ComponentStatusBadge, {
      props: { status: "ready" },
    });
    expect(wrapper.text()).toBe("Ready");
    expect(wrapper.classes()).toContain("ComponentStatusBadge_ready");
  });

  it("defaults to Pending for unknown status", () => {
    const wrapper = mount(ComponentStatusBadge, {
      props: { status: "something_weird" },
    });
    expect(wrapper.text()).toBe("Pending");
  });
});
