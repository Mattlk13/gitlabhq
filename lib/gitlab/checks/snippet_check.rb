# frozen_string_literal: true

module Gitlab
  module Checks
    class SnippetCheck < BaseChecker
      ERROR_MESSAGES = {
        create_delete_branch: 'You can not create or delete branches.'
      }.freeze

      ATTRIBUTES = %i[oldrev newrev ref branch_name tag_name logger].freeze
      attr_reader(*ATTRIBUTES)

      def initialize(change, logger:)
        @oldrev, @newrev, @ref = change.values_at(:oldrev, :newrev, :ref)
        @branch_name = Gitlab::Git.branch_name(@ref)
        @tag_name = Gitlab::Git.tag_name(@ref)

        @logger = logger
        @logger.append_message("Running checks for ref: #{@branch_name || @tag_name}")
      end

      def exec
        if creation? || deletion?
          raise GitAccess::ForbiddenError, ERROR_MESSAGES[:create_delete_branch]
        end

        # TODO: https://gitlab.com/gitlab-org/gitlab/issues/205628
        # Check operation will not result in more than one file in the repository

        true
      end
    end
  end
end
