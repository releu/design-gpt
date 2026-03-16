<template>
  <Layout layout="overlay" @close="goBack">
    <template #content>
      <div class="FigmaExport__card">
        <div class="FigmaExport__text">{{ resolvedShareCode }}</div>
      </div>
    </template>
  </Layout>
</template>

<script>
import { useAuth0 } from "@auth0/auth0-vue";

export default {
  setup() {
    const { getAccessTokenSilently } = useAuth0();
    return { getAccessTokenSilently };
  },
  props: {
    id: { type: String, default: null },
    iterationId: { type: String, default: null },
    shareCode: { type: String, default: null },
  },
  data() {
    return { resolvedShareCode: this.shareCode || "" };
  },
  methods: {
    goBack() {
      if (this.shareCode) {
        this.$router.push({ name: "shared-design", params: { shareCode: this.shareCode } });
      } else {
        this.$router.push({ name: "design", params: { id: this.id } });
      }
    },
    async fetchShareCode() {
      if (this.shareCode) {
        this.resolvedShareCode = this.shareCode;
        return;
      }
      const token = await this.getAccessTokenSilently({
        authorizationParams: { audience: import.meta.env.VITE_AUTH0_AUDIENCE },
      });
      const res = await fetch(`/api/designs/${this.id}`, {
        headers: { Authorization: `Bearer ${token}` },
      });
      if (!res.ok) return;
      const data = await res.json();
      const iter = (data.iterations || []).find(
        (i) => String(i.id) === this.iterationId
      );
      if (iter) this.resolvedShareCode = iter.share_code;
    },
  },
  mounted() {
    this.fetchShareCode();
  },
};
</script>

<style lang="scss">
.FigmaExport__card {
  background: var(--white);
  border-radius: 24px;
  padding: 24px;
}

.FigmaExport__text {
  font: var(--font-basic);
  color: var(--black);
}
</style>
