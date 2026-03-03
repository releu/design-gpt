import { mount } from "@vue/test-utils";
import WizardStepper from "./WizardStepper.vue";

describe("WizardStepper", () => {
  const steps = ["Prompt", "Libraries", "Components", "Organize"];

  it("renders all step labels", () => {
    const wrapper = mount(WizardStepper, {
      props: { steps, currentStep: 0 },
    });
    const labels = wrapper.findAll(".WizardStepper__label");
    expect(labels).toHaveLength(4);
    expect(labels[0].text()).toBe("Prompt");
    expect(labels[3].text()).toBe("Organize");
  });

  it("marks the current step as active", () => {
    const wrapper = mount(WizardStepper, {
      props: { steps, currentStep: 1 },
    });
    const stepEls = wrapper.findAll(".WizardStepper__step");
    expect(stepEls[1].classes()).toContain("WizardStepper__step_active");
    expect(stepEls[0].classes()).toContain("WizardStepper__step_completed");
    expect(stepEls[2].classes()).toContain("WizardStepper__step_upcoming");
  });

  it("emits go-to when a step is clicked", async () => {
    const wrapper = mount(WizardStepper, {
      props: { steps, currentStep: 2 },
    });
    await wrapper.findAll(".WizardStepper__step")[1].trigger("click");
    expect(wrapper.emitted("go-to")).toEqual([[1]]);
  });

  it("shows step numbers", () => {
    const wrapper = mount(WizardStepper, {
      props: { steps, currentStep: 0 },
    });
    const numbers = wrapper.findAll(".WizardStepper__number");
    expect(numbers[0].text()).toBe("1");
    expect(numbers[3].text()).toBe("4");
  });
});
