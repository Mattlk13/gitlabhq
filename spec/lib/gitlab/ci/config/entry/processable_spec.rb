# frozen_string_literal: true

require 'spec_helper'

describe Gitlab::Ci::Config::Entry::Processable do
  let(:node_class) do
    Class.new(::Gitlab::Config::Entry::Node) do
      include Gitlab::Ci::Config::Entry::Processable

      def self.name
        'job'
      end
    end
  end

  let(:entry) { node_class.new(config, name: :rspec) }

  describe 'validations' do
    before do
      entry.compose!
    end

    context 'when entry config value is correct' do
      let(:config) { { stage: 'test' } }

      describe '#valid?' do
        it 'is valid' do
          expect(entry).to be_valid
        end
      end

      context 'when job name is empty' do
        let(:entry) { node_class.new(config, name: ''.to_sym) }

        it 'reports error' do
          expect(entry.errors).to include "job name can't be blank"
        end
      end
    end

    context 'when entry value is not correct' do
      context 'incorrect config value type' do
        let(:config) { ['incorrect'] }

        describe '#errors' do
          it 'reports error about a config type' do
            expect(entry.errors)
              .to include 'job config should be a hash'
          end
        end
      end

      context 'when config is empty' do
        let(:config) { {} }

        describe '#valid' do
          it 'is invalid' do
            expect(entry).not_to be_valid
          end
        end
      end

      context 'when extends key is not a string' do
        let(:config) { { extends: 123 } }

        it 'returns error about wrong value type' do
          expect(entry).not_to be_valid
          expect(entry.errors).to include "job extends should be an array of strings or a string"
        end
      end

      context 'when it uses both "when:" and "rules:"' do
        let(:config) do
          {
            script: 'echo',
            when: 'on_failure',
            rules: [{ if: '$VARIABLE', when: 'on_success' }]
          }
        end

        it 'returns an error about when: being combined with rules' do
          expect(entry).not_to be_valid
          expect(entry.errors).to include 'job config key may not be used with `rules`: when'
        end
      end

      context 'when only: is used with rules:' do
        let(:config) { { only: ['merge_requests'], rules: [{ if: '$THIS' }] } }

        it 'returns error about mixing only: with rules:' do
          expect(entry).not_to be_valid
          expect(entry.errors).to include /may not be used with `rules`/
        end

        context 'and only: is blank' do
          let(:config) { { only: nil, rules: [{ if: '$THIS' }] } }

          it 'returns error about mixing only: with rules:' do
            expect(entry).not_to be_valid
            expect(entry.errors).to include /may not be used with `rules`/
          end
        end

        context 'and rules: is blank' do
          let(:config) { { only: ['merge_requests'], rules: nil } }

          it 'returns error about mixing only: with rules:' do
            expect(entry).not_to be_valid
            expect(entry.errors).to include /may not be used with `rules`/
          end
        end
      end

      context 'when except: is used with rules:' do
        let(:config) { { except: { refs: %w[master] }, rules: [{ if: '$THIS' }] } }

        it 'returns error about mixing except: with rules:' do
          expect(entry).not_to be_valid
          expect(entry.errors).to include /may not be used with `rules`/
        end

        context 'and except: is blank' do
          let(:config) { { except: nil, rules: [{ if: '$THIS' }] } }

          it 'returns error about mixing except: with rules:' do
            expect(entry).not_to be_valid
            expect(entry.errors).to include /may not be used with `rules`/
          end
        end

        context 'and rules: is blank' do
          let(:config) { { except: { refs: %w[master] }, rules: nil } }

          it 'returns error about mixing except: with rules:' do
            expect(entry).not_to be_valid
            expect(entry.errors).to include /may not be used with `rules`/
          end
        end
      end

      context 'when only: and except: are both used with rules:' do
        let(:config) do
          {
            only: %w[merge_requests],
            except: { refs: %w[master] },
            rules: [{ if: '$THIS' }]
          }
        end

        it 'returns errors about mixing both only: and except: with rules:' do
          expect(entry).not_to be_valid
          expect(entry.errors).to include /may not be used with `rules`/
          expect(entry.errors).to include /may not be used with `rules`/
        end

        context 'when only: and except: as both blank' do
          let(:config) do
            { only: nil, except: nil, rules: [{ if: '$THIS' }] }
          end

          it 'returns errors about mixing both only: and except: with rules:' do
            expect(entry).not_to be_valid
            expect(entry.errors).to include /may not be used with `rules`/
            expect(entry.errors).to include /may not be used with `rules`/
          end
        end

        context 'when rules: is blank' do
          let(:config) do
            { only: %w[merge_requests], except: { refs: %w[master] }, rules: nil }
          end

          it 'returns errors about mixing both only: and except: with rules:' do
            expect(entry).not_to be_valid
            expect(entry.errors).to include /may not be used with `rules`/
            expect(entry.errors).to include /may not be used with `rules`/
          end
        end
      end
    end
  end

  describe '#relevant?' do
    it 'is a relevant entry' do
      entry = node_class.new({ stage: 'test' }, name: :rspec)

      expect(entry).to be_relevant
    end
  end

  describe '#compose!' do
    let(:specified) do
      double('specified', 'specified?' => true, value: 'specified')
    end

    let(:unspecified) { double('unspecified', 'specified?' => false) }
    let(:default) { double('default', '[]' => unspecified) }
    let(:workflow) { double('workflow', 'has_rules?' => false) }
    let(:deps) { double('deps', 'default' => default, '[]' => unspecified, 'workflow' => workflow) }

    context 'with workflow rules' do
      using RSpec::Parameterized::TableSyntax

      where(:name, :has_workflow_rules?, :only, :rules, :result) do
        "uses default only"    | false | nil          | nil    | { refs: %w[branches tags] }
        "uses user only"       | false | %w[branches] | nil    | { refs: %w[branches] }
        "does not define only" | false | nil          | []     | nil
        "does not define only" | true  | nil          | nil    | nil
        "uses user only"       | true  | %w[branches] | nil    | { refs: %w[branches] }
        "does not define only" | true  | nil          | []     | nil
      end

      with_them do
        let(:config) { { script: 'ls', rules: rules, only: only }.compact }

        it "#{name}" do
          expect(workflow).to receive(:has_rules?) { has_workflow_rules? }

          entry.compose!(deps)

          expect(entry.only_value).to eq(result)
        end
      end
    end

    context 'when workflow rules is used' do
      context 'when rules are used' do
        let(:config) { { script: 'ls', cache: { key: 'test' }, rules: [] } }

        it 'does not define only' do
          expect(entry).not_to be_only_defined
        end
      end

      context 'when rules are not used' do
        let(:config) { { script: 'ls', cache: { key: 'test' }, only: [] } }

        it 'does not define only' do
          expect(entry).not_to be_only_defined
        end
      end
    end
  end

  context 'when composed' do
    before do
      entry.compose!
    end

    describe '#value' do
      context 'when entry is correct' do
        let(:config) do
          { stage: 'test' }
        end

        it 'returns correct value' do
          expect(entry.value)
            .to eq(name: :rspec,
                   stage: 'test',
                   only: { refs: %w[branches tags] })
        end
      end
    end
  end
end
