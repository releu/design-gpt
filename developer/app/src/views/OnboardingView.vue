<template>
  <OnboardingLayout>
    <template #header>
      <div class="OnboardingView__header">New Project Setup</div>
    </template>

    <template #stepper>
      <WizardStepper
        :steps="stepNames"
        :currentStep="currentStep"
        @go-to="goToStep"
      />
    </template>

    <template #content>
      <OnboardingStepPrompt
        v-if="currentStep === 0"
        v-model="prompt"
      />

      <OnboardingStepLibraries
        v-else-if="currentStep === 1"
        :availableLibraries="availableLibraries"
        :selectedLibraryIds="selectedLibraryIds"
        :importing="importing"
        :importProgress="importProgress"
        :importError="importError"
        @toggle-library="toggleLibrary"
        @import-figma="importFigmaFile"
      />

      <OnboardingStepComponents
        v-else-if="currentStep === 2"
        :componentSets="componentSets"
        :components="standaloneComponents"
        @select-component="selectComponent"
      />

      <OnboardingStepOrganize
        v-else-if="currentStep === 3"
        :componentSets="componentSets"
        :components="standaloneComponents"
        @toggle-root="handleToggleRoot"
        @toggle-child="handleToggleChild"
      />
    </template>

    <template #footer>
      <button
        v-if="currentStep > 0"
        class="OnboardingView__btn OnboardingView__btn_back"
        @click="currentStep--"
      >
        Back
      </button>
      <div v-else />

      <button
        v-if="currentStep < stepNames.length - 1"
        :class="nextButtonClasses"
        @click="nextStep"
      >
        Next
      </button>
      <button
        v-else
        class="OnboardingView__btn OnboardingView__btn_finish"
        @click="finishOnboarding"
      >
        Create Project
      </button>
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
      currentStep: 0,
      stepNames: ["Prompt", "Libraries", "Components", "Organize"],
      prompt: "",
      availableLibraries: [],
      selectedLibraryIds: [],
      importing: false,
      importProgress: {},
      importError: "",
      importingLibraryId: null,
      componentSets: [],
      standaloneComponents: [],
      pollTimer: null,
    };
  },
  computed: {
    nextButtonClasses() {
      return {
        OnboardingView__btn: true,
        OnboardingView__btn_next: true,
        OnboardingView__btn_disabled: !this.canProceed,
      };
    },
    canProceed() {
      if (this.currentStep === 0) return this.prompt.length > 0;
      if (this.currentStep === 1) return this.selectedLibraryIds.length > 0;
      return true;
    },
  },
  methods: {
    async getToken() {
      return this.getAccessTokenSilently({
        authorizationParams: { audience: import.meta.env.VITE_AUTH0_AUDIENCE },
      });
    },
    async fetchJson(url, options = {}) {
      const token = await this.getToken();
      const res = await fetch(url, {
        credentials: "include",
        headers: {
          Authorization: `Bearer ${token}`,
          "Content-Type": "application/json",
          ...options.headers,
        },
        ...options,
      });
      return res.json();
    },
    goToStep(index) {
      if (index < this.currentStep) {
        this.currentStep = index;
      }
    },
    nextStep() {
      if (this.canProceed && this.currentStep < this.stepNames.length - 1) {
        this.currentStep++;
        if (this.currentStep === 1) this.loadAvailableLibraries();
        if (this.currentStep === 2) this.loadComponents();
      }
    },
    async loadAvailableLibraries() {
      const data = await this.fetchJson("/api/component-libraries/available");
      this.availableLibraries = data;
    },
    async loadComponents() {
      this.componentSets = [];
      this.standaloneComponents = [];

      for (const libId of this.selectedLibraryIds) {
        const data = await this.fetchJson(
          `/api/component-libraries/${libId}/components`,
        );
        this.componentSets.push(...(data.component_sets || []));
        this.standaloneComponents.push(...(data.components || []));
      }
    },
    toggleLibrary(id) {
      const index = this.selectedLibraryIds.indexOf(id);
      if (index === -1) {
        this.selectedLibraryIds.push(id);
      } else {
        this.selectedLibraryIds.splice(index, 1);
      }
    },
    async importFigmaFile(url) {
      this.importing = true;
      this.importError = "";
      this.importProgress = {};

      try {
        const data = await this.fetchJson("/api/component-libraries", {
          method: "POST",
          body: JSON.stringify({ url }),
        });

        this.importingLibraryId = data.id;
        this.selectedLibraryIds.push(data.id);

        // Trigger sync
        await this.fetchJson(`/api/component-libraries/${data.id}/sync`, {
          method: "POST",
        });

        // Poll for progress
        this.startPolling(data.id);
      } catch (e) {
        this.importing = false;
        this.importError = "Import failed. Please check the URL and try again.";
      }
    },
    startPolling(libraryId) {
      this.stopPolling();
      this.pollTimer = setInterval(async () => {
        const data = await this.fetchJson(
          `/api/component-libraries/${libraryId}`,
        );
        this.importProgress = data.progress || {};

        if (data.status === "ready" || data.status === "error") {
          this.stopPolling();
          this.importing = false;

          if (data.status === "error") {
            this.importError =
              data.progress?.error || "Import failed unexpectedly.";
          } else {
            await this.loadAvailableLibraries();
          }
        }
      }, 2000);
    },
    stopPolling() {
      if (this.pollTimer) {
        clearInterval(this.pollTimer);
        this.pollTimer = null;
      }
    },
    selectComponent(component) {
      // Placeholder for Phase 5 detail modal
    },
    async handleToggleRoot(item) {
      const isComponentSet = item.variants_count !== undefined;
      const endpoint = isComponentSet
        ? `/api/component-sets/${item.id}`
        : `/api/components/${item.id}`;
      const paramKey = isComponentSet ? "component_set" : "component";

      await this.fetchJson(endpoint, {
        method: "PATCH",
        body: JSON.stringify({
          [paramKey]: { is_root: !item.is_root },
        }),
      });

      item.is_root = !item.is_root;
    },
    async handleToggleChild({ parent, childId }) {
      const children = parent.allowed_children || [];
      const index = children.indexOf(childId);
      if (index === -1) {
        children.push(childId);
      } else {
        children.splice(index, 1);
      }

      const isComponentSet = parent.variants_count !== undefined;
      const endpoint = isComponentSet
        ? `/api/component-sets/${parent.id}`
        : `/api/components/${parent.id}`;
      const paramKey = isComponentSet ? "component_set" : "component";

      await this.fetchJson(endpoint, {
        method: "PATCH",
        body: JSON.stringify({
          [paramKey]: { allowed_children: children },
        }),
      });

      parent.allowed_children = [...children];
    },
    async finishOnboarding() {
      const data = await this.fetchJson("/api/projects", {
        method: "POST",
        body: JSON.stringify({
          project: {
            name: this.prompt.slice(0, 64),
            description: this.prompt,
          },
        }),
      });

      const projectId = data.id;

      // Link selected libraries to project
      for (const libId of this.selectedLibraryIds) {
        await this.fetchJson(
          `/api/projects/${projectId}/component-libraries`,
          {
            method: "POST",
            body: JSON.stringify({ component_library_id: libId }),
          },
        );
      }

      this.$router.push({ name: "home" });
    },
  },
  beforeUnmount() {
    this.stopPolling();
  },
};
</script>
