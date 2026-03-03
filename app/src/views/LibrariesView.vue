<template>
  <OnboardingLayout>
    <template #header>
      <div>Component Libraries</div>
    </template>

    <template #content>
      <div v-if="libraries.length > 0" class="LibrariesView__list">
        <LibraryCard
          v-for="lib in libraries"
          :key="lib.id"
          :library="lib"
          @select="viewLibrary"
        />
      </div>

      <div class="LibrariesView__import">
        <FigmaUrlInput
          v-model="figmaUrl"
          :importing="importing"
          :error="importError"
          @import="importFigmaFile"
        />
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
  data() {
    return {
      libraries: [],
      figmaUrl: "",
      importing: false,
      importError: "",
    };
  },
  methods: {
    async getToken() {
      return this.getAccessTokenSilently({
        authorizationParams: { audience: import.meta.env.VITE_AUTH0_AUDIENCE },
      });
    },
    async loadLibraries() {
      const token = await this.getToken();
      const res = await fetch("/api/component-libraries", {
        credentials: "include",
        headers: { Authorization: `Bearer ${token}` },
      });
      this.libraries = await res.json();
    },
    viewLibrary(library) {
      this.$router.push({
        name: "library_detail",
        params: { id: library.id },
      });
    },
    async importFigmaFile(url) {
      this.importing = true;
      this.importError = "";

      try {
        const token = await this.getToken();
        const res = await fetch("/api/component-libraries", {
          method: "POST",
          credentials: "include",
          headers: {
            Authorization: `Bearer ${token}`,
            "Content-Type": "application/json",
          },
          body: JSON.stringify({ url }),
        });
        const data = await res.json();

        // Trigger sync
        await fetch(`/api/component-libraries/${data.id}/sync`, {
          method: "POST",
          credentials: "include",
          headers: { Authorization: `Bearer ${token}` },
        });

        this.importing = false;
        this.figmaUrl = "";
        await this.loadLibraries();
      } catch (e) {
        this.importing = false;
        this.importError = "Import failed.";
      }
    },
  },
  async mounted() {
    await this.loadLibraries();
  },
};
</script>
