<template>
  <div class="MechaNode">
    <div class="MechaNode__header" @click="open = !open">
      <span class="MechaNode__chevron" :class="{ MechaNode__chevron_open: open }">▸</span>
      <span class="MechaNode__name">{{ node.component }}</span>
      <span
        class="MechaNode__remove"
        @click.stop="mechaRemoveNode(path)"
      >×</span>
    </div>

    <div class="MechaNode__body" v-if="open">
      <!-- Props -->
      <MechaNodeProps
        :node="node"
        :path="path"
        :componentDef="componentDef"
      />

      <!-- Slots -->
      <div
        v-for="slot in slots"
        :key="slot.name"
        class="MechaNode__slot"
      >
        <div class="MechaNode__slot-label">{{ slot.name }}</div>
        <MechaNode
          v-for="(child, i) in (node[slot.name] || [])"
          :key="i"
          :node="child"
          :path="[...path, slot.name, i]"
          :schema="schema"
        />
        <div class="MechaNode__add">
          <div class="MechaNode__add-btn" @click.stop="toggleAddMenu(slot.name)">+ add</div>
          <div
            v-if="addMenuSlot === slot.name"
            class="MechaNode__add-menu"
          >
            <div
              v-for="child in slot.allowed_children"
              :key="child"
              class="MechaNode__add-menu-item"
              @click.stop="addChild(slot.name, child)"
            >{{ child }}</div>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script>
export default {
  name: "MechaNode",
  inject: ["mechaRemoveNode", "mechaAddChild"],
  props: {
    node: { type: Object, required: true },
    path: { type: Array, required: true },
    schema: { type: Object, required: true },
  },
  data() {
    return {
      open: true,
      addMenuSlot: null,
    };
  },
  computed: {
    componentDef() {
      return this.schema[this.node.component] || null;
    },
    slots() {
      if (!this.componentDef) return [];
      return (this.componentDef.slots || [])
        .map((s) => ({
          name: s.name,
          allowed_children: (s.allowed_children || []).filter((c) => c in this.schema),
        }))
        .filter((s) => s.allowed_children.length);
    },
  },
  methods: {
    toggleAddMenu(slotName) {
      this.addMenuSlot = this.addMenuSlot === slotName ? null : slotName;
    },
    addChild(slotName, componentName) {
      this.addMenuSlot = null;
      this.mechaAddChild(this.path, slotName, componentName);
    },
  },
};
</script>

<style lang="scss">
.MechaNode {
  font: var(--font-basic);

  &__header {
    display: flex;
    align-items: center;
    gap: 6px;
    padding: 4px 6px;
    cursor: pointer;
    border-radius: 6px;

    &:hover {
      background: var(--fill);
    }
  }

  &__chevron {
    font-size: 10px;
    color: var(--darkgray);
    width: 14px;
    text-align: center;
    transition: transform 150ms ease;
    flex-shrink: 0;

    &_open {
      transform: rotate(90deg);
    }
  }

  &__name {
    font-weight: 600;
    color: var(--black);
  }

  &__remove {
    margin-left: auto;
    width: 18px;
    height: 18px;
    display: flex;
    align-items: center;
    justify-content: center;
    border-radius: 4px;
    color: var(--darkgray);
    font-size: 14px;
    cursor: pointer;

    &:hover {
      background: var(--fill);
      color: var(--black);
    }
  }

  &__body {
    padding-left: 20px;
    display: flex;
    flex-direction: column;
    gap: 4px;
    padding-top: 4px;
  }

  &__slot {
    display: flex;
    flex-direction: column;
    gap: 2px;
  }

  &__slot-label {
    font: var(--font-basic);
    color: var(--darkgray);
    padding: 2px 6px;
    font-size: 11px;
  }

  &__add {
    position: relative;
    padding: 0 6px;
  }

  &__add-btn {
    font: var(--font-basic);
    font-size: 11px;
    color: var(--darkgray);
    cursor: pointer;
    padding: 2px 0;

    &:hover {
      color: var(--black);
    }
  }

  &__add-menu {
    position: absolute;
    top: 100%;
    left: 6px;
    background: var(--white);
    border-radius: 8px;
    box-shadow: 0 4px 24px rgba(0, 0, 0, 0.12);
    z-index: 10;
    min-width: 140px;
    padding: 4px 0;
    max-height: 200px;
    overflow-y: auto;
  }

  &__add-menu-item {
    padding: 6px 12px;
    font: var(--font-basic);
    cursor: pointer;

    &:hover {
      background: var(--fill);
    }
  }
}
</style>
