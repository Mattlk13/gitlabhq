<!-- eslint-disable vue/multi-word-component-names -->
<script>
import { GlLoadingIcon, GlTooltipDirective, GlButton, GlButtonGroup } from '@gitlab/ui';
import { s__ } from '~/locale';

export default {
  i18n: {
    buttonLabel: s__('Badges|Reload badge image'),
  },
  // name: 'Badge' is a false positive: https://gitlab.com/gitlab-org/frontend/eslint-plugin-i18n/issues/25
  // eslint-disable-next-line @gitlab/require-i18n-strings
  name: 'Badge',
  components: {
    GlLoadingIcon,
    GlButton,
    GlButtonGroup,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  props: {
    imageUrl: {
      type: String,
      required: true,
    },
    linkUrl: {
      type: String,
      required: true,
    },
  },
  data() {
    return {
      hasError: false,
      isLoading: true,
      numRetries: 0,
    };
  },
  computed: {
    imageUrlWithRetries() {
      if (this.numRetries === 0) {
        return this.imageUrl;
      }

      return `${this.imageUrl}#retries=${this.numRetries}`;
    },
  },
  watch: {
    imageUrl() {
      this.hasError = false;
      this.isLoading = true;
      this.numRetries = 0;
    },
  },
  methods: {
    onError() {
      this.isLoading = false;
      this.hasError = true;
    },
    onLoad() {
      this.isLoading = false;
    },
    reloadImage() {
      this.hasError = false;
      this.isLoading = true;
      this.numRetries += 1;
    },
  },
};
</script>

<template>
  <div>
    <a
      v-show="!isLoading && !hasError"
      :href="linkUrl"
      target="_blank"
      rel="noopener noreferrer"
      data-testid="badge-image-link"
      :data-qa-link-url="linkUrl"
    >
      <img
        :src="imageUrlWithRetries"
        class="project-badge"
        aria-hidden="true"
        @load="onLoad"
        @error="onError"
      />
    </a>

    <gl-loading-icon v-show="isLoading" size="sm" :inline="true" />

    <gl-button-group v-show="hasError">
      <gl-button disabled icon="doc-image" />
      <gl-button disabled>
        {{ s__('Badges|No badge image') }}
      </gl-button>
    </gl-button-group>

    <gl-button
      v-show="hasError"
      v-gl-tooltip.hover
      :title="$options.i18n.buttonLabel"
      :aria-label="$options.i18n.buttonLabel"
      category="tertiary"
      variant="confirm"
      type="button"
      icon="retry"
      size="small"
      @click="reloadImage"
    />
  </div>
</template>
