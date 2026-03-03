<template>
  <div class="Section">
    <slot />
  </div>
</template>

<style lang="scss">
.Section {
  display: flex;
  flex-direction: column;
  height: 100%;

  & > * {
    flex-shrink: 0;
  }

  .PromptField {
    flex-grow: 1;
  }
}
</style>
