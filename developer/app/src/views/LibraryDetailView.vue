<template>
  <OnboardingLayout>
    <template #header>
      <div v-if="library" class="LibraryDetail__name">{{ library.name }}</div>
    </template>

    <template #content>
      <div v-if="loading">Loading...</div>

      <div v-else-if="library">
        <div v-if="library.status !== 'ready'" class="LibraryDetailView__status">
          <ComponentStatusBadge :status="library.status" />
          <ProgressBar
            v-if="library.progress"
            :value="library.progress.step_number || 0"
            :max="library.progress.total_steps || 4"
            :label="library.progress.message || ''"
          />
        </div>

        <OnboardingStepComponents
          :componentSets="componentSets"
          :components="components"
        />
      </div>
    </template>

    <template #footer>
      <div
        class="LibraryDetailView__back"
        @click="$router.push({ name: 'libraries' })"
      >
        Back to Libraries
      </div>
    </template>
  </OnboardingLayout>
</template>

<script>
import { useAuth0 } from "@auth0/auth0-vue";

export default {
  setup() {
    const { getAccessTokenSilently } = useAuth0();
    return { getAccessTokenSilently };
  },
  props: {
    id: {
      type: String,
      required: true,
    },
  },
  data() {
    return {
      library: null,
      componentSets: [],
      components: [],
      loading: true,
    };
  },
  methods: {
    async getToken() {
      return this.getAccessTokenSilently({
        authorizationParams: { audience: import.meta.env.VITE_AUTH0_AUDIENCE },
      });
    },
    async loadLibrary() {
      const token = await this.getToken();

      const libRes = await fetch(`/api/component-libraries/${this.id}`, {
        credentials: "include",
        headers: { Authorization: `Bearer ${token}` },
      });
      this.library = await libRes.json();

      const compRes = await fetch(
        `/api/component-libraries/${this.id}/components`,
        {
          credentials: "include",
          headers: { Authorization: `Bearer ${token}` },
        },
      );
      const compData = await compRes.json();
      this.componentSets = compData.component_sets || [];
      this.components = compData.components || [];

      this.loading = false;
    },
  },
  async mounted() {
    await this.loadLibrary();
  },
};
</script>
