# frozen_string_literal: true

class FinalizeBackfillProjectsRedirectRoutesNamespaceId < Gitlab::Database::Migration[2.3]
  milestone '18.2'
  disable_ddl_transaction!

  restrict_gitlab_migration gitlab_schema: :gitlab_main_cell

  def up
    ensure_batched_background_migration_is_finished(
      job_class_name: 'BackfillProjectsRedirectRoutesNamespaceId',
      table_name: :redirect_routes,
      column_name: :id,
      job_arguments: [],
      finalize: true
    )
  end

  def down; end
end
