<template>
  <div class="ChatPanel">
    <div class="ChatPanel__label">CHAT</div>
    <div class="ChatPanel__messages" ref="messagesList">
      <div v-if="!messages || !messages.length" class="ChatPanel__empty">
        No messages yet
      </div>
      <div
        v-for="msg in messages"
        :key="msg.id"
        :class="['ChatPanel__message', `ChatPanel__message_${msg.author}`]"
      >
        <div class="ChatPanel__message-author">{{ authorLabel(msg.author) }}</div>
        <div class="ChatPanel__message-body" v-html="msg.html" />
      </div>
    </div>
    <div class="ChatPanel__input-area">
      <textarea
        class="ChatPanel__input"
        v-model="inputText"
        placeholder="Improve this design..."
        :disabled="sending"
        @keydown.enter.ctrl.prevent="send"
      />
      <div
        class="ChatPanel__send"
        :class="{ 'ChatPanel__send_disabled': !inputText.trim() || sending }"
        @click="send"
      >
        Send
      </div>
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
  },
  emits: ["sent"],
  data() {
    return {
      inputText: "",
      sending: false,
    };
  },
  methods: {
    async getToken() {
      return this.getAccessTokenSilently({
        authorizationParams: { audience: import.meta.env.VITE_AUTH0_AUDIENCE },
      });
    },
    authorLabel(author) {
      if (author === "user") return "You";
      if (author === "designer") return "Designer";
      if (author === "art_director") return "Art Director";
      return author;
    },
    async send() {
      if (!this.inputText.trim() || this.sending) return;
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
  background: white;
  border-radius: 24px;
  padding: 24px;
  display: flex;
  flex-direction: column;
  height: 100%;
  box-sizing: border-box;
  gap: 16px;

  &__label {
    font: var(--font-text-s);
    color: var(--gray);
    text-transform: uppercase;
    letter-spacing: 0.05em;
    flex-shrink: 0;
  }

  &__messages {
    flex: 1;
    overflow-y: auto;
    display: flex;
    flex-direction: column;
    gap: 12px;
    min-height: 0;

    &::-webkit-scrollbar {
      display: none;
    }
  }

  &__empty {
    font: var(--font-text-m);
    color: var(--gray);
    text-align: center;
    padding-top: 24px;
  }

  &__message {
    display: flex;
    flex-direction: column;
    gap: 4px;

    &_user {
      align-items: flex-end;

      .ChatPanel__message-body {
        background: var(--orange);
        color: white;
      }
    }

    &_designer,
    &_art_director {
      align-items: flex-start;
    }
  }

  &__message-author {
    font: var(--font-text-s);
    color: var(--gray);
    padding: 0 4px;
  }

  &__message-body {
    background: var(--superlightgray);
    border-radius: 12px;
    padding: 10px 14px;
    font: var(--font-text-m);
    max-width: 85%;
    line-height: 1.5;
  }

  &__input-area {
    flex-shrink: 0;
    display: flex;
    flex-direction: column;
    gap: 8px;
  }

  &__input {
    border: 1px solid var(--lightgray);
    border-radius: 12px;
    padding: 12px;
    font: var(--font-text-m);
    resize: none;
    height: 72px;
    width: 100%;
    box-sizing: border-box;
    outline: none;
    transition: border-color 150ms ease;

    &:focus {
      border-color: var(--orange);
    }

    &:disabled {
      opacity: 0.6;
    }
  }

  &__send {
    background: var(--orange);
    color: white;
    border-radius: 32px;
    padding: 12px 24px;
    font: var(--font-text-m);
    cursor: pointer;
    text-align: center;
    transition: transform 150ms ease;

    &:active {
      transform: scale(0.95);
    }

    &_disabled {
      opacity: 0.4;
      cursor: default;
      pointer-events: none;
    }
  }
}
</style>
