<script>
import { GlAvatarsInline, GlAvatar, GlAvatarLink, GlTooltipDirective, GlBadge } from '@gitlab/ui';
import { n__ } from '~/locale';

const AVATAR_TOOLTIP_MAX_CHARS = 100;
export const MAX_VISIBLE_AVATARS = 4;
export const AVATAR_SIZE = 24;

export default {
  name: 'ProtectionRow',
  AVATAR_TOOLTIP_MAX_CHARS,
  MAX_VISIBLE_AVATARS,
  AVATAR_SIZE,
  components: { GlAvatarsInline, GlAvatar, GlAvatarLink, GlBadge },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  props: {
    title: {
      type: String,
      required: false,
      default: null,
    },
    accessLevels: {
      type: Array,
      required: false,
      default: () => [],
    },
    showDivider: {
      type: Boolean,
      required: false,
      default: false,
    },
    users: {
      type: Array,
      required: false,
      default: () => [],
    },
    groups: {
      type: Array,
      required: false,
      default: () => [],
    },
    statusCheckUrl: {
      type: String,
      required: false,
      default: null,
    },
  },
  computed: {
    avatarBadgeSrOnlyText() {
      return n__(
        '%d additional user',
        '%d additional users',
        this.users.length - this.$options.MAX_VISIBLE_AVATARS,
      );
    },
    usersAndGroups() {
      return [...this.users, ...this.groups];
    },
  },
};
</script>

<template>
  <div
    class="gl-display-flex gl-align-items-center gl-gap-7 gl-border-gray-100 gl-mb-4 gl-border-t-1"
    :class="{ 'gl-border-t-solid gl-pt-4': showDivider }"
  >
    <div class="gl-display-flex gl-w-full gl-align-items-center">
      <div class="gl-flex-basis-quarter">{{ title }}</div>

      <div v-if="statusCheckUrl" class="gl-flex-grow-1">{{ statusCheckUrl }}</div>

      <gl-avatars-inline
        v-if="usersAndGroups.length"
        class="!gl-w-1/4"
        :avatars="usersAndGroups"
        :collapsed="true"
        :max-visible="$options.MAX_VISIBLE_AVATARS"
        :avatar-size="$options.AVATAR_SIZE"
        badge-tooltip-prop="name"
        :badge-tooltip-max-chars="$options.AVATAR_TOOLTIP_MAX_CHARS"
        :badge-sr-only-text="avatarBadgeSrOnlyText"
      >
        <template #avatar="{ avatar }">
          <gl-avatar-link
            :key="avatar.name"
            v-gl-tooltip
            target="_blank"
            :href="avatar.webUrl"
            :title="avatar.name"
          >
            <gl-avatar
              :src="avatar.avatarUrl"
              :label="avatar.name"
              :entity-name="avatar.name"
              :alt="avatar.name"
              :size="$options.AVATAR_SIZE"
            />
          </gl-avatar-link>
        </template>
      </gl-avatars-inline>

      <gl-badge
        v-for="(item, index) in accessLevels"
        :key="index"
        class="gl-mr-2"
        data-testid="access-level"
        :data-qa-role="item.accessLevelDescription"
      >
        {{ item.accessLevelDescription }}
      </gl-badge>
    </div>
  </div>
</template>
