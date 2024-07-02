# frozen_string_literal: true

class AddMergeRequestsClosingIssuesProjectIdFk < Gitlab::Database::Migration[2.2]
  milestone '17.2'
  disable_ddl_transaction!

  def up
    add_concurrent_foreign_key :merge_requests_closing_issues, :projects, column: :project_id, on_delete: :cascade
  end

  def down
    with_lock_retries do
      remove_foreign_key :merge_requests_closing_issues, column: :project_id
    end
  end
end
