# frozen_string_literal: true

class AddSbomOccurrencesVulnerabilitiesProjectIdTrigger < Gitlab::Database::Migration[2.2]
  milestone '17.1'

  def up
    install_sharding_key_assignment_trigger(
      table: :sbom_occurrences_vulnerabilities,
      sharding_key: :project_id,
      parent_table: :sbom_occurrences,
      parent_sharding_key: :project_id,
      foreign_key: :sbom_occurrence_id
    )
  end

  def down
    remove_sharding_key_assignment_trigger(
      table: :sbom_occurrences_vulnerabilities,
      sharding_key: :project_id,
      parent_table: :sbom_occurrences,
      parent_sharding_key: :project_id,
      foreign_key: :sbom_occurrence_id
    )
  end
end
