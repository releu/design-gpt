<template>
  <div class="ModuleCode">
    <Codemirror
      v-model="localValue"
      :extensions="extensions"
      :style="{ height }"
      @change="onChange"
    />
  </div>
</template>

<script>
import { ref, watch, computed } from "vue";
import { Codemirror } from "vue-codemirror";
import { basicSetup } from "codemirror";
import { markdown } from "@codemirror/lang-markdown";
import { json as jsonLang } from "@codemirror/lang-json";
import { javascript } from "@codemirror/lang-javascript";
import { EditorView, placeholder, highlightWhitespace } from "@codemirror/view";
import { EditorState } from "@codemirror/state";
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
  name: "ModuleCode",
  components: { Codemirror },
  props: {
    modelValue: { type: String, default: "" },
    placeholder: { type: String, default: "<code>" },
    language: { type: String, default: "markdown" },
    height: { type: String, default: "100%" },
    readOnly: { type: Boolean, default: false },
  },
  emits: ["update:modelValue", "change"],
  setup(props, { emit }) {
    const localValue = ref(props.modelValue);
    watch(
      () => props.modelValue,
      (v) => {
        if (v !== localValue.value) localValue.value = v;
      },
    );

    const langExt = computed(() => {
      if (props.language === "json") return jsonLang();
      if (props.language === "javascript") return javascript({ jsx: true });
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
      if (props.readOnly) {
        exts.push(EditorView.editable.of(false));
        exts.push(EditorState.readOnly.of(true));
      }
      return exts;
    });

    function onChange(val) {
      emit("update:modelValue", val);
      emit("change", val);
    }

    return { localValue, extensions, onChange };
  },
};
</script>

<style lang="scss">
.ModuleCode {
  .cm-editor {
    border: 0;
    width: 100%;
    height: 100%;
    box-sizing: border-box;
    font: var(--font-basic);
    background: #fff;
    color: #111827;
  }

  .cm-gutters {
    margin-right: 4px;
  }

  .cm-focused {
    outline: 0;
  }

  .cm-content {
    padding: 0;
  }

  .cm-scroller {
    padding: 0;
    overflow: auto;
    font-family: Menlo, monospace !important;
    font-size: 15px;
  }

  .cm-activeLine {
    background-color: #a0c7fe;
    background-color: transparent;
    border-radius: 6px;

    .cm-placeholder {
      color: rgba(255, 255, 255, 0.8);
    }
  }

  .cm-activeLineGutter {
    background-color: transparent;
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
