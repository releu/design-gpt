<template>
  <div class="Menu">
    <div class="Menu__item" v-for="item in items">
      <RouterLink :to="item.route">
        <div class="Menu__item-text">
          {{ item.name }}
        </div>
      </RouterLink>
    </div>
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
};
</script>

<style lang="scss">
.Menu {
  width: 100%;

  &__item {
    a {
      display: block;
      padding: 1px 2px;
      text-decoration: none;
      color: var(--black);

      &.router-link-active .Menu__item-text {
        background: var(--superlightgray);
      }

      &:hover .Menu__item-text {
        background: var(--superlightgray);
      }
    }

    &-text {
      padding: 8px 10px;
      border-radius: 14px;
    }
  }
}
</style>
