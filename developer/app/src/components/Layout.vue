<template>
  <div class="Layout">
    <div class="Layout__main">
      <SectionHeader>design</SectionHeader>
      <Select v-model="projectSelectorValue" :values="allProjects" />
      <slot name="main" />
      <div class="Layout__main-footer">
        <Button @click="signOut">sign out</Button>
      </div>
    </div>
    <div class="Layout__menu" v-if="$slots['menu-1']">
      <slot name="menu-1" />
    </div>
    <div class="Layout__menu" v-if="$slots['menu-2']">
      <slot name="menu-2" />
    </div>
    <div
      class="Layout__detail"
      v-if="
        $slots['detail-top'] ||
        $slots['detail-bottom'] ||
        $slots['detail-top-left']
      "
    >
      <div class="Layout__detail-top">
        <template v-if="$slots['detail-top']">
          <slot name="detail-top" />
        </template>
        <template v-if="$slots['detail-top-left']">
          <div class="Layout__detail-top-left">
            <slot name="detail-top-left" />
          </div>
          <div class="Layout__detail-top-right">
            <slot name="detail-top-right" />
          </div>
        </template>
      </div>
      <div class="Layout__detail-bottom">
        <slot name="detail-bottom" />
      </div>
    </div>
  </div>
</template>

<script>
import { useAuth0 } from "@auth0/auth0-vue";

export default {
  props: {
    currentProject: String,
  },
  setup() {
    const { getAccessTokenSilently, logout } = useAuth0();
    return { getAccessTokenSilently, logout };
  },
  data() {
    return {
      projectSelectorValue: this.currentProject,
      allProjects: [],
    };
  },
  async mounted() {
    const token = await this.getAccessTokenSilently({
      authorizationParams: { audience: import.meta.env.VITE_AUTH0_AUDIENCE },
    });
    fetch("/api/projects", {
      method: "GET",
      credentials: "include",
      headers: {
        Authorization: `Bearer ${token}`,
      },
    })
      .then((data) => data.json())
      .then((data) => {
        this.allProjects = data.map((p) => {
          return {
            id: p.id,
            name: p.name,
          };
        });
      });
  },
  methods: {
    async signOut() {
      await this.logout({ logoutParams: { returnTo: window.location.origin } });
    },
  },
  watch: {
    projectSelectorValue(to, from) {
      this.$router.push({
        name: "project_ux",
        params: { project_id: String(to) },
      });
    },
  },
};
</script>

<style lang="scss">
.Layout {
  display: flex;
  height: 100vh;

  &__main {
    width: 200px;
    flex-shrink: 0;
    border-right: 1px solid var(--lightgray);
    display: flex;
    flex-direction: column;
    align-items: flex-start;
    box-sizing: border-box;

    .Select + .Menu {
      margin-top: 24px;
    }

    &-footer {
      position: absolute;
      bottom: 0;
      left: 0;
    }
  }

  &__menu {
    width: 200px;
    flex-shrink: 0;
    border-right: 1px solid var(--lightgray);
    overflow-y: auto;
    overflow-x: hidden;
  }

  &__detail {
    flex-grow: 1;
    display: flex;
    flex-direction: column;

    &-top,
    &-bottom {
      flex-grow: 1;
      flex-shrink: 0;
      flex-basis: 100px;
      height: 50%;
      overflow-y: auto;
      box-sizing: border-box;
    }

    &-bottom {
      border-top: 1px solid var(--lightgray);
    }

    &-top {
      display: flex;

      &-left,
      &-right {
        flex-grow: 1;
        flex-shrink: 0;
        flex-basis: 100px;
      }

      &-left {
        border-right: 1px solid var(--lightgray);
      }
    }
  }
}
</style>
