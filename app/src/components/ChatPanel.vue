<template>
  <div class="ChatPanel" qa="chat-panel">
    <div class="ChatPanel__messages" qa="chat-messages" ref="messagesList">
      <div class="ChatPanel__messages-spacer" />
      <div
        v-for="msg in messages"
        :key="msg.id"
        :class="['ChatPanel__message', `ChatPanel__message_${msg.author}`]"
        :qa="msg.author === 'user' ? 'chat-message-user' : 'chat-message-ai'"
      >
        <div class="ChatPanel__message-body" v-html="msg.html || msg.content || msg.body || ''" />
        <div
          v-if="msg.author === 'designer' && msg.iteration_id"
          class="ChatPanel__reset-btn"
          @click="$emit('reset', msg.iteration_id)"
        >revert to this version</div>
      </div>
    </div>
    <div class="ChatPanel__input-area">
      <input
        type="text"
        class="ChatPanel__input"
        qa="chat-input"
        v-model="inputText"
        placeholder="Type a message..."
        :disabled="sending || generating"
        @keydown="onKeydown"
      />
      <button
        class="ChatPanel__send"
        qa="chat-send"
        :disabled="!canSend"
        @click="send"
      >
        <svg class="ChatPanel__send-icon" width="14" height="14" viewBox="0 0 14 14" fill="none">
          <path d="M1 13L13 7L1 1V5.5L8 7L1 8.5V13Z" fill="currentColor"/>
        </svg>
      </button>
    </div>
  </div>
</template>

<script>
import { useAuth0 } from "@auth0/auth0-vue";

export default {
  name: "ChatPanel",
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
      inputText: "",
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
.ChatPanel {
  background: var(--bg-panel);
  border-radius: var(--radius-lg);
  padding: var(--sp-3);
  display: flex;
  flex-direction: column;
  height: 100%;
  box-sizing: border-box;
  gap: 0;
  overflow: hidden;

  &__messages {
    flex: 1;
    overflow-y: auto;
    display: flex;
    flex-direction: column;
    gap: 8px;
    min-height: 0;
    padding-bottom: var(--sp-3);

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
    flex-direction: column;
    flex-shrink: 0;

    /* CRITICAL: User = LEFT, plain text, no bubble */
    &_user {
      align-items: flex-start;
      text-align: left;

      .ChatPanel__message-body {
        background-color: transparent;
        color: var(--text-primary);
        padding: 0;
        border-radius: 0;
        font: var(--font-text-m);
        text-align: left;
      }
    }

    /* AI/designer = RIGHT, gray bubble */
    &_designer,
    &_art_director {
      align-items: flex-end;
      text-align: right;

      .ChatPanel__message-body {
        background-color: #F0EFED;
        color: var(--text-primary);
        border-radius: 16px;
        padding: 8px 16px;
        text-align: left;
      }
    }
  }

  &__message-body {
    font: var(--font-text-m);
    max-width: 75%;
    line-height: 1.5;
    word-wrap: break-word;
    overflow-wrap: break-word;
  }

  &__reset-btn {
    font: var(--font-text-s);
    color: var(--gray);
    cursor: pointer;
    margin-top: 4px;

    &:hover {
      color: var(--orange);
    }
  }

  /* Input bar: pill-shaped, light gray bg */
  &__input-area {
    flex-shrink: 0;
    display: flex;
    align-items: center;
    background: var(--bg-chip-active);
    border-radius: var(--radius-pill);
    height: 44px;
    padding: 0 6px 0 var(--sp-3);
    gap: var(--sp-2);
  }

  &__input {
    flex: 1;
    border: none;
    background: transparent;
    font: var(--font-text-m);
    outline: none;
    height: 100%;
    padding: 0;
    color: var(--text-primary);
    min-width: 0;

    &::placeholder {
      color: var(--text-secondary);
    }

    &:disabled {
      opacity: 0.6;
    }
  }

  /* Send button: solid black circle */
  &__send {
    position: relative;
    z-index: 1;
    width: 32px;
    height: 32px;
    min-width: 32px;
    border-radius: 50%;
    border: none;
    padding: 0;
    background: var(--accent-primary);
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
    color: var(--text-on-dark);
  }
}
</style>
