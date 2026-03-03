<template>
  <div class="OnboardingStepOrganize">
    <div class="OnboardingStepOrganize__title">Organize components</div>
    <div class="OnboardingStepOrganize__subtitle">
      Mark root components and configure which children they can contain.
    </div>

    <div class="OnboardingStepOrganize__layout">
      <div class="OnboardingStepOrganize__list">
        <div
          v-for="item in allItems"
          :key="item.id"
          :class="itemClasses(item)"
          @click="selectItem(item)"
        >
          <label class="OnboardingStepOrganize__root-toggle">
            <input
              type="checkbox"
              :checked="item.is_root"
              @change.stop="$emit('toggle-root', item)"
            />
            Root
          </label>
          <span class="OnboardingStepOrganize__item-name">{{ item.name }}</span>
        </div>
      </div>

      <div v-if="selectedItem" class="OnboardingStepOrganize__config">
        <div class="OnboardingStepOrganize__config-title">
          {{ selectedItem.name }}
        </div>
        <div class="OnboardingStepOrganize__config-subtitle">
          Allowed children:
        </div>
        <div
          v-for="child in otherItems"
          :key="child.id"
          class="OnboardingStepOrganize__child-row"
        >
          <label>
            <input
              type="checkbox"
              :checked="isAllowedChild(child.id)"
              @change="$emit('toggle-child', { parent: selectedItem, childId: child.id })"
            />
            {{ child.name }}
          </label>
        </div>
      </div>

      <div v-else class="OnboardingStepOrganize__config OnboardingStepOrganize__config_empty">
        Select a component to configure its children.
      </div>
    </div>
  </div>
</template>

<script>
export default {
  name: "OnboardingStepOrganize",
  props: {
    componentSets: {
      type: Array,
      default: () => [],
    },
    components: {
      type: Array,
      default: () => [],
    },
  },
  emits: ["toggle-root", "toggle-child"],
  data() {
    return {
      selectedItemId: null,
    };
  },
  computed: {
    allItems() {
      return [...this.componentSets, ...this.components];
    },
    selectedItem() {
      if (!this.selectedItemId) return null;
      return this.allItems.find((item) => item.id === this.selectedItemId);
    },
    otherItems() {
      return this.allItems.filter((item) => item.id !== this.selectedItemId);
    },
  },
  methods: {
    selectItem(item) {
      this.selectedItemId = item.id;
    },
    itemClasses(item) {
      return {
        OnboardingStepOrganize__item: true,
        OnboardingStepOrganize__item_selected: item.id === this.selectedItemId,
        OnboardingStepOrganize__item_root: item.is_root,
      };
    },
    isAllowedChild(childId) {
      if (!this.selectedItem) return false;
      return (this.selectedItem.allowed_children || []).includes(childId);
    },
  },
};
</script>

<style lang="scss">
.OnboardingStepOrganize {
  background: var(--bg-panel);
  border-radius: var(--radius-lg);
  padding: var(--sp-4);

  &__title {
    font: var(--font-header-m);
    margin-bottom: 8px;
  }

  &__subtitle {
    font: var(--font-text-m);
    color: var(--gray);
    margin-bottom: 24px;
  }

  &__layout {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 24px;
    min-height: 300px;
  }

  &__list {
    border: 1px solid var(--superlightgray);
    border-radius: 16px;
    padding: 8px;
    overflow-y: auto;
    max-height: 400px;
  }

  &__item {
    display: flex;
    align-items: center;
    gap: 8px;
    padding: 10px 12px;
    border-radius: 12px;
    cursor: pointer;
    transition: background 100ms ease;

    &:hover {
      background: var(--superlightgray);
    }

    &_selected {
      background: var(--superlightgray);
    }

    &_root {
      .OnboardingStepOrganize__item-name {
        font-weight: bold;
      }
    }
  }

  &__root-toggle {
    display: flex;
    align-items: center;
    gap: 4px;
    font: var(--font-text-s);
    color: var(--gray);
    cursor: pointer;

    input {
      cursor: pointer;
    }
  }

  &__item-name {
    font: var(--font-text-m);
  }

  &__config {
    border: 1px solid var(--superlightgray);
    border-radius: 16px;
    padding: 20px;

    &_empty {
      display: flex;
      align-items: center;
      justify-content: center;
      font: var(--font-text-m);
      color: var(--gray);
    }
  }

  &__config-title {
    font: var(--font-bold-m);
    margin-bottom: 4px;
  }

  &__config-subtitle {
    font: var(--font-text-s);
    color: var(--gray);
    margin-bottom: 12px;
  }

  &__child-row {
    padding: 6px 0;

    label {
      display: flex;
      align-items: center;
      gap: 8px;
      cursor: pointer;
      font: var(--font-text-m);

      input {
        cursor: pointer;
      }
    }
  }
}
</style>
