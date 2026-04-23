<template>
  <div class="ModuleChat" qa="chat-panel">
    <div class="ModuleChat__messages" qa="chat-messages" ref="messagesList">
      <div class="ModuleChat__messages-spacer" />
      <div
        v-for="msg in messages"
        :key="msg.id"
        qa="chat-message"
      >
        <div
          v-if="msg.author === 'system'"
          class="ModuleChat__message ModuleChat__message_system"
          qa="chat-message-system"
        >
          <div class="ModuleChat__message-body">{{ msg.message }}</div>
          <button
            v-if="msg.action === 'rebuild'"
            class="ModuleChat__rebuild-btn"
            qa="rebuild-btn"
            @click="rebuild(msg)"
          >Rebuild design</button>
          <button
            v-else-if="msg.action === 'rebuild_started'"
            class="ModuleChat__rebuild-btn ModuleChat__rebuild-btn_disabled"
            qa="rebuild-btn"
            disabled
          >Rebuilding...</button>
        </div>
        <div
          v-else
          :class="['ModuleChat__message', `ModuleChat__message_${msg.author}`]"
          :qa="msg.author === 'user' ? 'chat-message-user' : 'chat-message-ai'"
        >
          <div class="ModuleChat__message-body" v-if="isThinking(msg)">{{ thinkingText }}</div>
          <div class="ModuleChat__message-body" v-else v-html="msg.html || msg.content || msg.body || ''" />
          <div
            v-if="msg.author === 'designer' && msg.iteration_id"
            class="ModuleChat__reset-btn"
            @click="$emit('reset', msg.iteration_id)"
          >revert to this version</div>
        </div>
      </div>
    </div>
    <div class="ModuleChat__input-area">
      <input
        type="text"
        class="ModuleChat__input"
        qa="chat-input"
        v-model="inputText"
        placeholder="Enter text..."
        :disabled="sending || generating || readonly"
        @keydown="onKeydown"
      />
      <button
        class="ModuleChat__send"
        qa="chat-send"
        :disabled="!canSend"
        @click="send"
      >
        <Icon class="ModuleChat__send-icon" type="ai" />
      </button>
    </div>
  </div>
</template>

<script>
import { useAuth0 } from "@auth0/auth0-vue";

const thinkingPhrases = [
  "creating...",
  "thinking...",
  "designing...",
  "sketching ideas...",
  "laying out components...",
  "picking colors...",
  "arranging pixels...",
  "composing layout...",
  "wiring up props...",
  "generating markup...",
  "iterating on design...",
  "refining details...",
  "building structure...",
  "connecting pieces...",
  "polishing edges...",
  "shaping the view...",
  "assembling blocks...",
  "tuning spacing...",
  "rendering concept...",
  "crafting interface...",
  "aligning elements...",
  "mapping hierarchy...",
];

export default {
  name: "ModuleChat",
  setup() {
    const { getAccessTokenSilently } = useAuth0();
    return { getAccessTokenSilently };
  },
  props: {
    messages: Array,
    designId: String,
    generating: {
      type: Boolean,
      default: false,
    },
    readonly: {
      type: Boolean,
      default: false,
    },
  },
  emits: ["sent", "reset"],
  data() {
    return {
      inputText: sessionStorage.getItem(`chat:${this.designId}:draft`) || "",
      sending: false,
      thinkingIndex: Math.floor(Math.random() * thinkingPhrases.length),
      thinkingTimer: null,
    };
  },
  computed: {
    canSend() {
      return this.inputText.trim().length > 0 && !this.sending && !this.generating && !this.readonly;
    },
    thinkingText() {
      return thinkingPhrases[this.thinkingIndex];
    },
    hasThinkingMessage() {
      return (this.messages || []).some((m) => this.isThinking(m));
    },
  },
  methods: {
    async getToken() {
      return this.getAccessTokenSilently({
        authorizationParams: { audience: import.meta.env.VITE_AUTH0_AUDIENCE },
      });
    },
    onKeydown(e) {
      if (e.key === "Enter" && !e.shiftKey) {
        e.preventDefault();
        this.send();
      }
    },
    isThinking(msg) {
      return msg.author === "designer" && msg.state === "thinking" && !msg.message;
    },
    startThinkingCycle() {
      if (this.thinkingTimer) return;
      this.thinkingTimer = setInterval(() => {
        let next;
        do {
          next = Math.floor(Math.random() * thinkingPhrases.length);
        } while (next === this.thinkingIndex);
        this.thinkingIndex = next;
      }, 10000);
    },
    stopThinkingCycle() {
      if (this.thinkingTimer) {
        clearInterval(this.thinkingTimer);
        this.thinkingTimer = null;
      }
    },
    async rebuild(msg) {
      try {
        const token = await this.getToken();
        await fetch(`/api/designs/${this.designId}/rebuild`, {
          method: "POST",
          credentials: "include",
          headers: {
            Authorization: `Bearer ${token}`,
            "Content-Type": "application/json",
          },
        });
        msg.action = "rebuild_started";
        this.$emit("sent");
      } catch (e) {
        console.warn("[ModuleChat] rebuild failed:", e);
      }
    },
    async send() {
      if (!this.canSend) return;
      this.sending = true;
      const comment = this.inputText.trim();
      this.inputText = "";
      try {
        const token = await this.getToken();
        await fetch(`/api/designs/${this.designId}/improve`, {
          method: "POST",
          credentials: "include",
          headers: {
            Authorization: `Bearer ${token}`,
            "Content-Type": "application/json",
          },
          body: JSON.stringify({ comment }),
        });
        this.$emit("sent");
      } finally {
        this.sending = false;
      }
    },
  },
  mounted() {
    if (this.hasThinkingMessage) this.startThinkingCycle();
  },
  beforeUnmount() {
    this.stopThinkingCycle();
  },
  watch: {
    inputText(val) {
      const key = `chat:${this.designId}:draft`;
      if (val) sessionStorage.setItem(key, val);
      else sessionStorage.removeItem(key);
    },
    hasThinkingMessage(val) {
      if (val) this.startThinkingCycle();
      else this.stopThinkingCycle();
    },
    messages() {
      this.$nextTick(() => {
        if (this.$refs.messagesList) {
          this.$refs.messagesList.scrollTop = this.$refs.messagesList.scrollHeight;
        }
      });
    },
  },
};
</script>

<style lang="scss">
.ModuleChat {
  background: var(--white);
  border-radius: var(--radius-lg);
  padding: 8px;
  display: flex;
  flex-direction: column;
  height: 100%;
  box-sizing: border-box;
  gap: 12px;
  width: 100%;
  overflow: hidden;

  &__messages {
    flex: 1;
    overflow-y: auto;
    display: flex;
    flex-direction: column;
    gap: 10px;
    min-height: 0;
    padding-bottom: 0;
    max-width: 640px;
    align-self: center;
    width: 100%;

    &::-webkit-scrollbar {
      display: none;
    }
  }

  /* Spacer pushes messages to bottom (gravity-anchored) */
  &__messages-spacer {
    flex: 1 1 auto;
  }

  &__message {
    display: flex;
    align-items: center;
    flex-shrink: 0;
    width: 100%;
    box-sizing: border-box;

    /* User = LEFT, plain text, no bubble, right padding */
    &_user {
      padding-right: 40px;

      .ModuleChat__message-body {
        flex: 1 0 0;
        background-color: transparent;
        color: var(--black);
        padding: 9px 0;
        border-radius: 18px;
        font: var(--font-basic);
      }
    }

    /* System = CENTERED, muted notification style */
    &_system {
      justify-content: center;
      flex-direction: column;
      align-items: center;
      gap: 8px;

      .ModuleChat__message-body {
        font: var(--font-caption);
        color: var(--darkgray);
        text-align: center;
      }
    }

    /* AI/designer = RIGHT, gray bubble, left padding */
    &_designer {
      justify-content: flex-end;
      padding-left: 40px;

      .ModuleChat__message-body {
        flex: 1 0 0;
        background-color: var(--fill);
        color: var(--black);
        border-radius: 18px;
        padding: 9px 14px;
      }
    }
  }

  &__message-body {
    font: var(--font-basic);
    line-height: normal; word-spacing: -0.5px; font-kerning: none;
    word-wrap: break-word;
    overflow-wrap: break-word;
  }

  &__rebuild-btn {
    font: var(--font-basic);
    color: var(--white);
    background: var(--black);
    border: none;
    border-radius: var(--radius-pill);
    padding: 6px 16px;
    cursor: pointer;
    transition: transform 100ms ease;

    &:active {
      transform: scale(0.96);
    }

    &_disabled {
      opacity: 0.4;
      cursor: default;
      pointer-events: none;
    }
  }

  &__reset-btn {
    font: var(--font-basic);
    color: var(--darkgray);
    cursor: pointer;
    margin-top: 4px;

    &:hover {
      color: var(--black);
    }
  }

  /* Input bar: pill-shaped, light gray bg */
  &__input-area {
    flex-shrink: 0;
    display: flex;
    align-items: center;
    background: var(--fill);
    border-radius: var(--radius-pill);
    height: 48px;
    padding: 0 6px 0 var(--sp-3);
    gap: var(--sp-2);
  }

  &__input {
    flex: 1;
    border: none;
    background: transparent;
    font: var(--font-basic);
    outline: none;
    height: 100%;
    padding: 0;
    color: var(--black);
    min-width: 0;

    &::placeholder {
      color: var(--darkgray);
    }

    &:disabled {
      opacity: 0.6;
    }
  }

  /* Send button: solid black circle */
  &__send {
    position: relative;
    z-index: 1;
    width: 36px;
    height: 36px;
    min-width: 36px;
    border-radius: 50%;
    border: none;
    padding: 0;
    background: var(--black);
    display: flex;
    align-items: center;
    justify-content: center;
    cursor: pointer;
    transition: transform 100ms ease, opacity 100ms ease;
    flex-shrink: 0;

    &:active {
      transform: scale(0.9);
    }

    &:disabled {
      
      cursor: default;
      pointer-events: none;
    }
  }

  &__send-icon {
    width: 20px;
    height: 20px;
  }
}
</style>
