<template>
  <textarea
    class="ModuleContentPrompt"
    qa="prompt"
    :value="modelValue"
    :placeholder="placeholder"
    @input="$emit('update:modelValue', $event.target.value)"
  />
</template>

<script>
export default {
  name: "ModuleContentPrompt",
  props: {
    modelValue: { type: String, default: "" },
    placeholder: { type: String, default: "type..." },
    autofocus: { type: Boolean, default: false },
  },
  emits: ["update:modelValue"],
  mounted() {
    if (this.autofocus) this.$el.focus();
  },
};
</script>

<style lang="scss">
.ModuleContentPrompt {
  width: 100%;
  height: 100%;
  border: none;
  outline: none;
  resize: none;
  background: transparent;
  font: var(--font-basic);
  color: var(--black);
  box-sizing: border-box;

  &::placeholder {
    color: var(--darkgray);
  }
}
</style>
