# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SystemNoteMetadata do
  describe 'associations' do
    it { is_expected.to belong_to(:note) }
    it { is_expected.to belong_to(:description_version) }
  end

  describe 'validation' do
    it { is_expected.to validate_presence_of(:note) }

    context 'when action type is invalid' do
      subject do
        build(:system_note_metadata, note: build(:note), action: 'invalid_type')
      end

      it { is_expected.to be_invalid }
    end

    %i[merge timeline_event requested_changes].each do |action|
      context 'when action type is valid' do
        subject do
          build(:system_note_metadata, note: build(:note), action: action)
        end

        it { is_expected.to be_valid }
      end
    end

    context 'when importing' do
      subject do
        build(:system_note_metadata, note: nil, action: 'merge', importing: true)
      end

      it { is_expected.to be_valid }
    end
  end
end
