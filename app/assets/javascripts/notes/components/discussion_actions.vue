<script>
import DiscussionReplyPlaceholder from './discussion_reply_placeholder.vue';
import ResolveDiscussionButton from './discussion_resolve_button.vue';
import ResolveWithIssueButton from './discussion_resolve_with_issue_button.vue';

export default {
  name: 'DiscussionActions',
  components: {
    DiscussionReplyPlaceholder,
    ResolveDiscussionButton,
    ResolveWithIssueButton,
  },
  props: {
    discussion: {
      type: Object,
      required: true,
    },
    isResolving: {
      type: Boolean,
      required: true,
    },
    resolveButtonTitle: {
      type: String,
      required: true,
    },
    resolveWithIssuePath: {
      type: String,
      required: false,
      default: '',
    },
    // eslint-disable-next-line vue/no-unused-properties -- shouldShowJumpToNextDiscussion is part of the component's public API.
    shouldShowJumpToNextDiscussion: {
      type: Boolean,
      required: true,
    },
  },
  computed: {
    resolvableNotes() {
      return this.discussion.notes.filter((x) => x.resolvable);
    },
    userCanResolveDiscussion() {
      return this.resolvableNotes.every((note) => note.current_user?.can_resolve_discussion);
    },
  },
};
</script>

<template>
  <div class="discussion-with-resolve-btn clearfix">
    <discussion-reply-placeholder @focus="$emit('showReplyForm')" />

    <div v-if="userCanResolveDiscussion" class="btn-group discussion-actions" role="group">
      <div class="btn-group">
        <resolve-discussion-button
          v-if="discussion.resolvable"
          data-testid="resolve-discussion-button"
          :is-resolving="isResolving"
          :button-title="resolveButtonTitle"
          @onClick="$emit('resolve')"
        />
      </div>
      <resolve-with-issue-button
        v-if="discussion.resolvable && resolveWithIssuePath"
        :url="resolveWithIssuePath"
      />
    </div>
  </div>
</template>
