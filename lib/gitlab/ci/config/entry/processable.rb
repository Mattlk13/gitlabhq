# frozen_string_literal: true

module Gitlab
  module Ci
    class Config
      module Entry
        ##
        # Entry that represents a CI/CD Processable (a job)
        #
        module Processable
          extend ActiveSupport::Concern

          include ::Gitlab::Config::Entry::Configurable
          include ::Gitlab::Config::Entry::Attributable
          include ::Gitlab::Config::Entry::Inheritable

          PROCESSABLE_ALLOWED_KEYS = %i[extends stage only except rules].freeze

          included do
            validations do
              validates :config, presence: true
              validates :name, presence: true
              validates :name, type: Symbol

              validates :config, disallowed_keys: {
                  in: %i[only except when start_in],
                  message: 'key may not be used with `rules`'
                },
                if: :has_rules?

              with_options allow_nil: true do
                validates :extends, array_of_strings_or_string: true
                validates :rules, array_of_hashes: true
              end
            end

            entry :stage, Entry::Stage,
              description: 'Pipeline stage this job will be executed into.',
              inherit: false

            entry :only, ::Gitlab::Ci::Config::Entry::Policy,
              description: 'Refs policy this job will be executed for.',
              default: ::Gitlab::Ci::Config::Entry::Policy::DEFAULT_ONLY,
              inherit: false

            entry :except, ::Gitlab::Ci::Config::Entry::Policy,
              description: 'Refs policy this job will be executed for.',
              inherit: false

            entry :rules, ::Gitlab::Ci::Config::Entry::Rules,
              description: 'List of evaluable Rules to determine job inclusion.',
              inherit: false,
              metadata: {
                allowed_when: %w[on_success on_failure always never manual delayed].freeze
              }

            helpers :stage, :only, :except, :rules

            attributes :extends, :rules
          end

          def compose!(deps = nil)
            super do
              has_workflow_rules = deps&.workflow&.has_rules?

              # If workflow:rules: or rules: are used
              # they are considered not compatible
              # with `only/except` defaults
              #
              # Context: https://gitlab.com/gitlab-org/gitlab/merge_requests/21742
              if has_rules? || has_workflow_rules
                # Remove only/except defaults
                # defaults are not considered as defined
                @entries.delete(:only) unless only_defined? # rubocop:disable Gitlab/ModuleWithInstanceVariables
                @entries.delete(:except) unless except_defined? # rubocop:disable Gitlab/ModuleWithInstanceVariables
              end

              yield if block_given?
            end
          end

          def name
            metadata[:name]
          end

          def overwrite_entry(deps, key, current_entry)
            deps.default[key] unless current_entry.specified?
          end

          def value
            { name: name,
              stage: stage_value,
              extends: extends,
              rules: rules_value,
              only: only_value,
              except: except_value }.compact
          end
        end
      end
    end
  end
end
