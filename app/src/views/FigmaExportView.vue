<template>
  <Layout layout="overlay" @close="goBack">
    <template #content>
      <div class="FigmaExport__card">
        <div class="FigmaExport__text">code: {{ shareCode }}</div>
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
    id: { type: String, required: true },
    iterationId: { type: String, required: true },
  },
  data() {
    return { shareCode: "" };
  },
  methods: {
    goBack() {
      this.$router.push({ name: "design", params: { id: this.id } });
    },
    async fetchShareCode() {
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
      if (iter) this.shareCode = iter.share_code;
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
  user-select: all;
}
</style>
