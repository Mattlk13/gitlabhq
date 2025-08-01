<script>
import { GlIcon, GlSkeletonLoader } from '@gitlab/ui';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import { InternalEvents } from '~/tracking';
import TooltipOnTruncate from '~/vue_shared/components/tooltip_on_truncate/tooltip_on_truncate.vue';
import RecentlyViewedItemsQuery from '../graphql/queries/recently_viewed_items.query.graphql';
import {
  EVENT_USER_FOLLOWS_LINK_ON_HOMEPAGE,
  TRACKING_LABEL_RECENTLY_VIEWED,
} from '../tracking_constants';
import VisibilityChangeDetector from './visibility_change_detector.vue';

const MAX_ITEMS = 10;

export default {
  components: { GlIcon, GlSkeletonLoader, VisibilityChangeDetector, TooltipOnTruncate },
  mixins: [InternalEvents.mixin()],
  data() {
    return {
      items: [],
      error: null,
    };
  },
  apollo: {
    items: {
      query: RecentlyViewedItemsQuery,
      update({ currentUser: { recentlyViewedItems = [] } = {} }) {
        return recentlyViewedItems
          .map((entry) => ({
            ...entry.item,
            viewedAt: entry.viewedAt,
            itemType: entry.itemType,
            // eslint-disable-next-line no-underscore-dangle
            icon: this.getIconForItemType(entry.item.__typename),
          }))
          .slice(0, MAX_ITEMS);
      },
      error(error) {
        Sentry.captureException(error);
        this.error = error;
      },
    },
  },
  computed: {
    isLoading() {
      return this.$apollo.queries.items.loading;
    },
  },
  methods: {
    reload() {
      this.error = null;
      this.$apollo.queries.items.refetch();
    },
    getIconForItemType(itemType) {
      const iconMap = {
        Issue: 'issues',
        MergeRequest: 'merge-request',
        Epic: 'epic',
      };
      return iconMap[itemType] || 'question';
    },
    handleItemClick(item) {
      this.trackEvent(EVENT_USER_FOLLOWS_LINK_ON_HOMEPAGE, {
        label: TRACKING_LABEL_RECENTLY_VIEWED,
        // eslint-disable-next-line no-underscore-dangle
        property: item.__typename,
      });
    },
  },
  MAX_ITEMS,
};
</script>

<template>
  <visibility-change-detector @visible="reload">
    <h2 class="gl-heading-4 gl-mb-4 gl-mt-0">{{ __('Recently viewed') }}</h2>

    <p v-if="error">
      {{
        s__(
          'HomePageRecentlyViewedWidget|Your recently viewed items are not available. Please refresh the page to try again.',
        )
      }}
    </p>
    <template v-else-if="isLoading">
      <gl-skeleton-loader v-for="i in $options.MAX_ITEMS" :key="i" :height="24">
        <rect x="0" y="0" width="16" height="16" rx="2" ry="2" />
        <rect x="24" y="0" width="200" height="16" rx="2" ry="2" />
      </gl-skeleton-loader>
    </template>

    <p v-else-if="!items.length">
      {{ __('Issues and merge requests you visit will appear here.') }}
    </p>
    <ul v-else class="gl-m-0 gl-flex gl-list-none gl-flex-col gl-gap-1 gl-p-0">
      <li v-for="item in items" :key="item.id">
        <a
          :href="item.webUrl"
          class="gl-flex gl-items-center gl-gap-2 gl-rounded-small gl-p-1 gl-text-default hover:gl-bg-subtle hover:gl-text-default hover:gl-no-underline"
          @click="handleItemClick(item)"
        >
          <gl-icon :name="item.icon" class="gl-shrink-0" />
          <tooltip-on-truncate
            :title="item.title"
            class="gl-min-w-0 gl-overflow-hidden gl-text-ellipsis gl-whitespace-nowrap"
          >
            {{ item.title }}
          </tooltip-on-truncate>
        </a>
      </li>
    </ul>
  </visibility-change-detector>
</template>
