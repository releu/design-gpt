<template>
  <span :class="badgeClasses">{{ label }}</span>
</template>

<script>
const STATUS_MAP = {
  pending: { label: "Pending", modifier: "pending" },
  importing: { label: "Importing", modifier: "importing" },
  converting: { label: "Converting", modifier: "converting" },
  comparing: { label: "Comparing", modifier: "comparing" },
  imported: { label: "Imported", modifier: "imported" },
  ready: { label: "Ready", modifier: "ready" },
  error: { label: "Error", modifier: "error" },
  skipped: { label: "Skipped", modifier: "skipped" },
};

export default {
  name: "ComponentStatusBadge",
  props: {
    status: {
      type: String,
      default: "pending",
    },
  },
  computed: {
    label() {
      return (STATUS_MAP[this.status] || STATUS_MAP.pending).label;
    },
    badgeClasses() {
      const modifier = (STATUS_MAP[this.status] || STATUS_MAP.pending).modifier;
      return {
        ComponentStatusBadge: true,
        [`ComponentStatusBadge_${modifier}`]: true,
      };
    },
  },
};
</script>

<style lang="scss">
.ComponentStatusBadge {
  display: inline-block;
  font: var(--font-text-s);
  padding: 2px 10px;
  border-radius: 12px;
  white-space: nowrap;

  &_pending,
  &_importing,
  &_converting,
  &_comparing {
    background: #fff3cd;
    color: #856404;
  }

  &_imported,
  &_ready {
    background: #d4edda;
    color: #155724;
  }

  &_error {
    background: #f8d7da;
    color: #721c24;
  }

  &_skipped {
    background: var(--superlightgray);
    color: var(--gray);
  }
}
</style>
