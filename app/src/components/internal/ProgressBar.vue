<template>
  <div class="ProgressBar">
    <div class="ProgressBar__track">
      <div
        class="ProgressBar__fill"
        :style="{ width: fillWidth }"
      />
    </div>
    <div v-if="label" class="ProgressBar__label">{{ label }}</div>
  </div>
</template>

<script>
export default {
  name: "ProgressBar",
  props: {
    value: {
      type: Number,
      default: 0,
    },
    max: {
      type: Number,
      default: 100,
    },
    label: {
      type: String,
      default: "",
    },
  },
  computed: {
    fillWidth() {
      if (this.max <= 0) return "0%";
      const pct = Math.min(100, Math.max(0, (this.value / this.max) * 100));
      return `${pct}%`;
    },
  },
};
</script>

<style lang="scss">
.ProgressBar {
  &__track {
    height: 6px;
    background: var(--fill);
    border-radius: 3px;
    overflow: hidden;
  }

  &__fill {
    height: 100%;
    background: var(--black);
    border-radius: 3px;
    transition: width 300ms ease;
  }

  &__label {
    font: var(--font-basic);
    color: var(--darkgray);
    margin-top: 4px;
  }
}
</style>
