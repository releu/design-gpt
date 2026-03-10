<template>
  <div class="TestCase" v-if="config">
    <!-- ===== COMPONENT TEST CASES ===== -->
    <template v-if="type === 'component'">

      <!-- Variants -->
      <template v-if="config.variants">
        <div v-for="variant in config.variants" :key="variant.name" class="TestCase__variant">
          <div class="TestCase__variant-label">{{ variant.name }}</div>
          <div class="TestCase__container" :style="containerStyle" :qa="`test-case-${variant.name}`">
            <!-- ModuleDesignSystem: override internal state -->
            <template v-if="name === 'ModuleDesignSystem'">
              <ModuleDesignSystem :ref="'ds-' + variant.name" v-bind="variant.props" />
            </template>
            <template v-else>
              <component :is="name" v-bind="variant.props" />
            </template>
          </div>
        </div>
      </template>

      <!-- Single component -->
      <template v-else>
        <div class="TestCase__container" :style="containerStyle" qa="test-case">

          <!-- Header: render with slot children -->
          <template v-if="name === 'Header'">
            <Header>
              <template #design-selector>
                <DesignSelector  />
              </template>
              <template #mode-selector>
                <ModeSelector :modelValue="0" />
              </template>
              <template #more-button>
                <MoreButton />
              </template>
              <template #preview-selector>
                <PreviewSelector modelValue="phone" />
              </template>
            </Header>
          </template>

          <!-- Preview: render the empty state panel (matches Figma) -->
          <template v-else-if="name === 'Preview'">
            <div class="TestCase__preview-standalone">
              <div class="Layout__preview-empty">
                <div class="Layout__preview-empty-text">preview</div>
              </div>
            </div>
          </template>

          <!-- Default: render component with props -->
          <template v-else>
            <component :is="name" v-bind="config.props" />
          </template>
        </div>
      </template>
    </template>

    <!-- ===== FRAME TEST CASES ===== -->
    <template v-else-if="type === 'frame'">
      <div class="TestCase__frame" :style="frameStyle" qa="test-case">

        <!-- HOME -->
        <template v-if="name === 'home'">
          <Layout layout="home">
            <template #design-selector>
              <DesignSelector  />
            </template>
            <template #mode-selector>
              <ModeSelector :modelValue="0" />
            </template>
            <template #more-button>
              <MoreButton />
            </template>
            <template #preview-selector>
              <PreviewSelector modelValue="phone" />
            </template>
            <template #prompt>
              <div class="TestCase__panel">
                <div class="TestCase__panel-label">prompt</div>
                <ModuleContentPrompt modelValue="" placeholder="describe what you want to create" />
              </div>
            </template>
            <template #design-system>
              <ModuleContentDesignSystem :design-systems="mockLibraries" modelValue="1" />
            </template>
            <template #ai-engine-info>
              <Module label="ai engine">
                <ModuleContentAIEngine />
              </Module>
            </template>
            <template #preview>
              <div class="Layout__preview-panel Layout__preview-panel_mobile">
                <div class="Layout__preview-empty">
                  <div class="Layout__preview-empty-text">preview</div>
                </div>
              </div>
            </template>
          </Layout>
        </template>

        <!-- DESIGN-PHONE -->
        <template v-else-if="name === 'design-phone'">
          <Layout layout="phone">
            <template #design-selector>
              <DesignSelector  />
            </template>
            <template #mode-selector>
              <ModeSelector :modelValue="0" />
            </template>
            <template #more-button>
              <MoreButton />
            </template>
            <template #preview-selector>
              <PreviewSelector modelValue="phone" />
            </template>
            <template #left-panel>
              <ModuleChat :messages="mockMessages" designId="1" />
            </template>
            <template #prompt><span /></template>
            <template #preview>
              <div class="Layout__preview-panel Layout__preview-panel_mobile">
                <div class="Layout__preview-empty">
                  <div class="Layout__preview-empty-text">preview</div>
                </div>
              </div>
            </template>
          </Layout>
        </template>

        <!-- DESIGN-DESKTOP -->
        <template v-else-if="name === 'design-desktop'">
          <Layout layout="desktop">
            <template #design-selector>
              <DesignSelector  />
            </template>
            <template #mode-selector>
              <ModeSelector :modelValue="0" />
            </template>
            <template #more-button>
              <MoreButton />
            </template>
            <template #preview-selector>
              <PreviewSelector modelValue="desktop" />
            </template>
            <template #left-panel>
              <ModuleChat :messages="mockMessages" designId="1" />
            </template>
            <template #prompt><span /></template>
            <template #preview>
              <div class="Layout__preview-panel Layout__preview-panel_desktop">
                <div class="Layout__preview-empty">
                  <div class="Layout__preview-empty-text">preview</div>
                </div>
              </div>
            </template>
          </Layout>
        </template>

        <!-- DESIGN-CODE -->
        <template v-else-if="name === 'design-code'">
          <Layout layout="code">
            <template #design-selector>
              <DesignSelector  />
            </template>
            <template #mode-selector>
              <ModeSelector :modelValue="0" />
            </template>
            <template #more-button>
              <MoreButton />
            </template>
            <template #preview-selector>
              <PreviewSelector modelValue="code" />
            </template>
            <template #left-panel>
              <ModuleChat :messages="mockMessages" designId="1" />
            </template>
            <template #prompt><span /></template>
            <template #code-editor>
              <div class="Layout__preview-panel" style="height: 100%;">
                <ModuleCode :modelValue="mockCode" language="markdown" />
              </div>
            </template>
            <template #preview>
              <div class="Layout__preview-panel Layout__preview-panel_mobile">
                <div class="Layout__preview-empty">
                  <div class="Layout__preview-empty-text">preview</div>
                </div>
              </div>
            </template>
          </Layout>
        </template>

        <!-- DESIGN-SETTINGS -->
        <template v-else-if="name === 'design-settings'">
          <Layout layout="phone">
            <template #design-selector>
              <DesignSelector  />
            </template>
            <template #mode-selector>
              <ModeSelector :modelValue="1" />
            </template>
            <template #more-button>
              <MoreButton />
            </template>
            <template #preview-selector>
              <PreviewSelector modelValue="phone" />
            </template>
            <template #left-panel>
              <div class="TestCase__settings-panel">
                <div class="TestCase__settings-browser">
                  <div class="TestCase__settings-menu">
                    <div class="TestCase__settings-menu-label">general</div>
                    <div class="TestCase__settings-menu-item TestCase__settings-menu-item_active">overview</div>
                    <div class="TestCase__settings-menu-label">figma file name</div>
                    <div class="TestCase__settings-menu-item">component name</div>
                    <div class="TestCase__settings-menu-item">component name</div>
                    <div class="TestCase__settings-menu-item">component name</div>
                    <div class="TestCase__settings-menu-item">component name</div>
                    <div class="TestCase__settings-menu-label">figma file name</div>
                    <div class="TestCase__settings-menu-item">component name</div>
                    <div class="TestCase__settings-menu-item">component name</div>
                  </div>
                  <div class="TestCase__settings-detail">
                    <div class="TestCase__settings-detail-label">system name</div>
                    <div class="TestCase__settings-detail-value"><strong>Depot</strong></div>
                    <div class="TestCase__settings-detail-label" style="margin-top:16px">figma files</div>
                    <div class="TestCase__settings-detail-link">🔗 <strong>Depot Lib</strong></div>
                    <div class="TestCase__settings-detail-link">🔗 <strong>Super icons</strong></div>
                    <div class="TestCase__settings-detail-action">Edit</div>
                  </div>
                </div>
              </div>
            </template>
            <template #prompt><span /></template>
            <template #preview>
              <div class="Layout__preview-panel Layout__preview-panel_mobile">
                <div class="Layout__preview-empty">
                  <div class="Layout__preview-empty-text">preview</div>
                </div>
              </div>
            </template>
          </Layout>
        </template>

        <!-- HOME-NEW-DESIGN-SYSTEM -->
        <template v-else-if="name === 'home-new-design-system'">
          <Layout layout="home">
            <template #design-selector>
              <DesignSelector  />
            </template>
            <template #mode-selector>
              <ModeSelector :modelValue="0" />
            </template>
            <template #more-button>
              <MoreButton />
            </template>
            <template #preview-selector>
              <PreviewSelector modelValue="phone" />
            </template>
            <template #prompt>
              <div class="TestCase__panel">
                <div class="TestCase__panel-label">prompt</div>
                <ModuleContentPrompt modelValue="" placeholder="describe what you want to create" />
              </div>
            </template>
            <template #design-system>
              <ModuleContentDesignSystem :design-systems="mockLibraries" modelValue="1" />
            </template>
            <template #ai-engine-info>
              <Module label="ai engine">
                <ModuleContentAIEngine />
              </Module>
            </template>
            <template #preview>
              <div class="Layout__preview-panel Layout__preview-panel_mobile">
                <div class="Layout__preview-empty">
                  <div class="Layout__preview-empty-text">preview</div>
                </div>
              </div>
            </template>
            <template #overlay>
              <ModuleDesignSystem ref="dsOverlay" />
            </template>
          </Layout>
        </template>

      </div>
    </template>
  </div>
  <div v-else class="TestCase__not-found">
    Not found: {{ type }}/{{ name }}
  </div>
</template>

<script>
import { components, frames, mockData } from "@/test-cases/config.js";

export default {
  name: "TestCaseView",
  props: {
    type: { type: String, required: true },
    name: { type: String, required: true },
  },
  data() {
    return {
      mockMessages: mockData.chatMessages,
      mockLibraries: mockData.libraries,
      mockCode: mockData.codeContent,
    };
  },
  computed: {
    config() {
      if (this.type === "component") return components[this.name] || null;
      if (this.type === "frame") return frames[this.name] || null;
      return null;
    },
    containerStyle() {
      if (!this.config) return {};
      return {
        width: `${this.config.width}px`,
        height: `${this.config.height}px`,
      };
    },
    frameStyle() {
      if (!this.config) return {};
      return {
        width: `${this.config.width}px`,
        height: `${this.config.height}px`,
      };
    },
  },
  mounted() {
    this.$nextTick(() => {
      this.setupModuleDesignSystemOverrides();
      this.setupOverlayOverrides();
    });
  },
  methods: {
    setupModuleDesignSystemOverrides() {
      if (this.type !== "component" || this.name !== "ModuleDesignSystem") return;
      const cfg = components.ModuleDesignSystem;
      if (!cfg.variants) return;

      for (const variant of cfg.variants) {
        const refKey = "ds-" + variant.name;
        const refs = this.$refs[refKey];
        const comp = Array.isArray(refs) ? refs[0] : refs;
        if (!comp) continue;

        if (variant.name === "view-new") {
          // Pre-populate URLs to match Figma
          comp.pendingUrls = [
            "https://www.figma.com/design/9UzId8cZXBggKGCxV7JJdY/Service?...",
            "https://www.figma.com/design/9UzId8cZXBggKGCxV7JJdY/Service?...",
          ];
        } else if (variant.name === "view-overview") {
          comp.figmaFiles = mockData.dsLibraries;
          comp.designSystemName = "Depot";
          comp.selectedItem = "overview";
        } else if (variant.name === "view-component") {
          comp.figmaFiles = mockData.dsLibraries;
          comp.designSystemName = "Depot";
          comp.selectedItem = mockData.dsLibraries[0].components[0];
        }
      }
    },
    setupOverlayOverrides() {
      if (this.type !== "frame" || this.name !== "home-new-design-system") return;
      const comp = this.$refs.dsOverlay;
      if (!comp) return;
      comp.pendingUrls = [
        "https://www.figma.com/design/9UzId8cZXBggKGCxV7JJdY/Service?...",
        "https://www.figma.com/design/9UzId8cZXBggKGCxV7JJdY/Service?...",
      ];
    },
  },
};
</script>

<style>
.TestCase {
  background: var(--fill);
  min-height: 100vh;
  padding: 24px;
  box-sizing: border-box;
}

.TestCase__variant {
  margin-bottom: 24px;
}

.TestCase__variant-label {
  font-family: monospace;
  font-size: 12px;
  color: var(--darkgray);
  margin-bottom: 8px;
}

.TestCase__container {
  overflow: hidden;
}

.TestCase__not-found {
  padding: 48px;
  text-align: center;
  font-family: monospace;
  color: var(--darkgray);
}

/* Preview empty state for isolated component test */
.TestCase__preview-standalone {
  width: 100%;
  height: 100%;
  box-sizing: border-box;
  background: var(--white);
  border-radius: 20px;
  border: 1px solid var(--black);
  position: relative;
  overflow: hidden;
}

/* Frame container: constrain Layout to exact Figma size */
.TestCase__frame {
  overflow: hidden;
  position: relative;
}

.TestCase__frame .Layout {
  height: 100% !important;
  min-height: 0 !important;
  min-width: 0 !important;
}

/* Panel styles (replicating HomeView scoped styles) */
.TestCase__panel {
  background: var(--white);
  border-radius: var(--radius-lg);
  padding: var(--sp-3);
  display: flex;
  flex-direction: column;
  height: 100%;
  box-sizing: border-box;
}

.TestCase__panel-label {
  font: var(--font-basic);
  color: var(--black);
  margin-bottom: var(--sp-2);
  flex-shrink: 0;
}

.TestCase__generate-btn {
  background: var(--black);
  color: var(--white);
  border: none;
  border-radius: var(--radius-pill);
  padding: 12px 24px;
  font: var(--font-basic);
  cursor: pointer;
  display: flex;
  align-items: center;
  gap: 6px;
}

.TestCase__ai-info {
  display: flex;
  align-items: baseline;
  gap: var(--sp-2);
  font: var(--font-basic);
}

.TestCase__ai-info-label {
  font: var(--font-basic);
  color: var(--darkgray);
}

.TestCase__ai-info-value {
  font: var(--font-basic);
  font-weight: 700;
}

.TestCase__ai-info-note {
  font: var(--font-basic);
  color: var(--darkgray);
}

/* Settings panel (for design-settings frame) */
.TestCase__settings-panel {
  background: var(--white);
  border-radius: var(--radius-lg);
  height: 100%;
  box-sizing: border-box;
  overflow: hidden;
}

.TestCase__settings-browser {
  display: grid;
  grid-template-columns: 200px 1fr;
  height: 100%;
}

.TestCase__settings-menu {
  overflow-y: auto;
  border-right: 1px solid var(--fill);
  padding: 24px 20px 24px 24px;
}

.TestCase__settings-menu-label {
  font: var(--font-basic);
  color: var(--darkgray);
  padding: 16px 10px 6px;
}

.TestCase__settings-menu-label:first-child {
  padding-top: 0;
}

.TestCase__settings-menu-item {
  padding: 7px 10px;
  border-radius: 8px;
  font: var(--font-basic);
  cursor: pointer;
}

.TestCase__settings-menu-item_active {
  background: var(--fill);
}

.TestCase__settings-detail {
  padding: 24px 24px 24px 32px;
}

.TestCase__settings-detail-label {
  font: var(--font-basic);
  color: var(--darkgray);
  margin-bottom: 4px;
}

.TestCase__settings-detail-value {
  font: var(--font-basic);
  margin-bottom: 8px;
}

.TestCase__settings-detail-link {
  font: var(--font-basic);
  margin-bottom: 4px;
}

.TestCase__settings-detail-action {
  font: var(--font-basic);
  color: var(--darkgray);
  margin-top: 12px;
  cursor: pointer;
}
</style>
