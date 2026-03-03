<template>
  <div class="SectionHeader">
    <template v-if="items.length > 0">
      <div class="SectionHeader__items">
        <div
          @click="setActiveItem(i)"
          :class="itemClasses(i)"
          v-for="(item, i) in items"
        >
          {{ item }}
        </div>
      </div>
      <div class="SectionHeader__content">
        <slot :name="currentSlotName" />
      </div>
    </template>
    <template v-else>
      <div class="SectionHeader__items">
        <slot />
      </div>
    </template>
  </div>
</template>

<script>
export default {
  props: {
    items: {
      type: Array,
      default: [],
    },
  },
  data() {
    return {
      activeItemIndex: 0,
    };
  },
  methods: {
    itemClasses(index) {
      return {
        SectionHeader__item: true,
        SectionHeader__item_active: index === this.activeItemIndex,
      };
    },
    setActiveItem(index) {
      this.activeItemIndex = index;
    },
  },
  computed: {
    currentSlotName() {
      return `item-${this.activeItemIndex}`;
    },
  },
};
</script>

<style lang="scss">
.SectionHeader {
  display: flex;
  flex-direction: column;
  position: relative;
  width: 100%;

  &__items {
    display: flex;
    gap: 12px;
    padding: 12px;
  }

  &__item {
    color: var(--gray);
    cursor: pointer;

    &_active {
      color: var(--black);
    }
  }

  &__content {
    flex-grow: 1;
    margin-top: 12px;
    flex-grow: 1;
    overflow-y: auto;

    display: flex;
    flex-direction: column;

    .PromptField {
      flex-grow: 1;
    }

    .Button {
      position: absolute;
      left: 0;
      bottom: 0;
      background: white;
    }
  }
}
</style>
