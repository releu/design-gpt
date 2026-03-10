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
          :class="['ModuleChat__message', `ModuleChat__message_${msg.author}`]"
          :qa="msg.author === 'user' ? 'chat-message-user' : 'chat-message-ai'"
        >
          <div class="ModuleChat__message-body" v-html="msg.html || msg.content || msg.body || ''" />
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
        :disabled="sending || generating"
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
  },
  emits: ["sent", "reset"],
  data() {
    return {
      inputText: sessionStorage.getItem(`chat:${this.designId}:draft`) || "",
      sending: false,
    };
  },
  computed: {
    canSend() {
      return this.inputText.trim().length > 0 && !this.sending && !this.generating;
    },
  },
  methods: {
    async getToken() {
      return this.getAccessTokenSilently({
        authorizationParams: { audience: import.meta.env.VITE_AUTH0_AUDIENCE },
      });
    },
    onKeydown(e) {
      if (e.key === "Enter" && (e.ctrlKey || e.metaKey)) {
        e.preventDefault();
        this.send();
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
  watch: {
    inputText(val) {
      const key = `chat:${this.designId}:draft`;
      if (val) sessionStorage.setItem(key, val);
      else sessionStorage.removeItem(key);
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
  gap: 0;
  max-width: 640px;
  overflow: hidden;

  &__messages {
    flex: 1;
    overflow-y: auto;
    display: flex;
    flex-direction: column;
    gap: 10px;
    min-height: 0;
    padding-bottom: 0;

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
    line-height: normal;
    word-wrap: break-word;
    overflow-wrap: break-word;
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
      opacity: 0.3;
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
