<template>
  <div class="ModuleContentPrompt" qa="prompt" ref="root">
    <Codemirror
      v-model="localValue"
      :extensions="extensions"
      :style="{ height }"
      @change="onChange"
    />
  </div>
</template>

<script>
import { ref, watch, computed, onMounted, nextTick, ref as vueRef } from "vue";
import { Codemirror } from "vue-codemirror";
import { basicSetup } from "codemirror";
import { markdown } from "@codemirror/lang-markdown";
import { json as jsonLang } from "@codemirror/lang-json";
import { EditorView, placeholder, highlightWhitespace } from "@codemirror/view";
import { githubLight } from "@uiw/codemirror-theme-github";

const noGutterNoActiveLine = EditorView.theme(
  {
    ".cm-gutters": { display: "none" },
    ".cm-content": { paddingLeft: "0 !important" },
    ".cm-activeLine": { backgroundColor: "transparent" },
    ".cm-activeLineGutter": { backgroundColor: "transparent" },
    "&.cm-editor.cm-focused": { outline: "none" },
  },
  { dark: false },
);

export default {
  name: "ModuleContentPrompt",
  components: { Codemirror },
  props: {
    modelValue: { type: String, default: "" },
    placeholder: { type: String, default: "type..." },
    language: { type: String, default: "markdown" },
    height: { type: String, default: "100%" },
  },
  emits: ["update:modelValue", "change"],
  setup(props, { emit }) {
    const root = vueRef(null);
    const localValue = ref(props.modelValue);
    watch(
      () => props.modelValue,
      (v) => {
        if (v !== localValue.value) localValue.value = v;
      },
    );

    const langExt = computed(() => {
      if (props.language === "json") return jsonLang();
      if (props.language === "auto") {
        const t = (localValue.value || "").trim();
        return t.startsWith("{") || t.startsWith("[") ? jsonLang() : markdown();
      }
      return markdown();
    });

    const extensions = computed(() => {
      const exts = [
        basicSetup,
        githubLight,
        noGutterNoActiveLine,
        langExt.value,
        EditorView.lineWrapping,
      ];

      if (props.language === "json") {
        exts.push(highlightWhitespace());
      }

      if (props.placeholder) exts.push(placeholder(props.placeholder));
      return exts;
    });

    function onChange(val) {
      emit("update:modelValue", val);
      emit("change", val);
    }

    onMounted(() => {
      nextTick(() => {
        if (root.value) {
          const cm = root.value.querySelector('.cm-content');
          if (cm) cm.setAttribute('qa', 'prompt-field');
        }
      });
    });

    return { root, localValue, extensions, onChange };
  },
};
</script>

<style lang="scss">
.ModuleContentPrompt {
  .cm-editor {
    border: 0;
    width: 100%;
    height: 100%;
    box-sizing: border-box;
    font: var(--font-text-m);
    background: #fff;
    color: #111827;
  }

  .cm-scroller {
    padding: 8px 6px;
    overflow: auto;
    font-family: var(--ff-mono) !important;
    font-size: 14px;
  }

  .cm-highlightSpace {
    background-image: radial-gradient(
      circle at 50% 55%,
      #aaa 10%,
      transparent 5%
    );
  }
}
</style>
