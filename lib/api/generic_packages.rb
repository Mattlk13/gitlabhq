# frozen_string_literal: true

module API
  class GenericPackages < ::API::Base
    GENERIC_PACKAGES_REQUIREMENTS = {
      package_name: API::NO_SLASH_URL_PART_REGEX,
      file_name: API::NO_SLASH_URL_PART_REGEX
    }.freeze

    ALLOWED_STATUSES = %w[default hidden].freeze

    feature_category :package_registry
    urgency :low

    before do
      require_packages_enabled!
      authenticate_non_get!
    end

    params do
      requires :id, types: [String, Integer], desc: 'The ID or URL-encoded path of the project'
    end

    resource :projects, requirements: API::NAMESPACE_OR_PROJECT_REQUIREMENTS do
      route_setting :authentication, job_token_allowed: true, basic_auth_personal_access_token: true, deploy_token_allowed: true

      namespace ':id/packages/generic' do
        namespace ':package_name/*package_version/(*path/):file_name', requirements: GENERIC_PACKAGES_REQUIREMENTS do
          desc 'Workhorse authorize generic package file' do
            detail 'This feature was introduced in GitLab 13.5'
            success code: 200
            failure [
              { code: 401, message: 'Unauthorized' },
              { code: 403, message: 'Forbidden' },
              { code: 404, message: 'Not Found' }
            ]
            tags %w[generic_packages]
          end

          route_setting :authentication, job_token_allowed: true, basic_auth_personal_access_token: true, deploy_token_allowed: true
          route_setting :authorization, job_token_policies: :admin_packages

          params do
            requires :package_name, type: String, desc: 'Package name', regexp: Gitlab::Regex.generic_package_name_regex, file_path: true
            requires :package_version, type: String, desc: 'Package version', regexp: Gitlab::Regex.generic_package_version_regex
            requires :file_name, type: String, desc: 'Package file name', regexp: Gitlab::Regex.generic_package_file_name_regex, file_path: true
            optional :status, type: String, values: ALLOWED_STATUSES, desc: 'Package status'
          end

          put 'authorize' do
            authorize_job_token_policies!(authorized_user_project)

            authorize_workhorse!(**authorize_workhorse_params).tap do
              protect_package!(declared_params[:package_name], :generic)
            end
          end

          desc 'Upload package file' do
            detail 'This feature was introduced in GitLab 13.5'
            success [
              { code: 200 },
              { code: 201 }
            ]
            failure [
              { code: 400, message: 'Bad Request' },
              { code: 401, message: 'Unauthorized' },
              { code: 403, message: 'Forbidden' },
              { code: 404, message: 'Not Found' }
            ]
            tags %w[generic_packages]
          end

          params do
            requires :package_name, type: String, desc: 'Package name', regexp: Gitlab::Regex.generic_package_name_regex, file_path: true
            requires :package_version, type: String, desc: 'Package version', regexp: Gitlab::Regex.generic_package_version_regex
            optional :path, type: String, desc: 'File directory path', file_path: true
            requires :file_name, type: String, desc: 'Package file name', regexp: Gitlab::Regex.generic_package_file_name_regex, file_path: true
            optional :status, type: String, values: ALLOWED_STATUSES, desc: 'Package status'
            requires :file, type: ::API::Validations::Types::WorkhorseFile, desc: 'The package file to be published (generated by Multipart middleware)', documentation: { type: 'file' }
            optional :select, type: String, values: %w[package_file]
          end

          route_setting :authentication, job_token_allowed: true, basic_auth_personal_access_token: true, deploy_token_allowed: true
          route_setting :authorization, job_token_policies: :admin_packages

          put do
            project = authorized_user_project

            authorize_upload!(project)
            authorize_job_token_policies!(project)
            bad_request!('File is too large') if max_file_size_exceeded?

            track_package_event('push_package', :generic, project: project, namespace: project.namespace)
            create_package_file_params = declared_params.merge(
              file_name: encoded_file_name,
              build: current_authenticated_job
            )

            response = ::Packages::Generic::CreatePackageFileService
              .new(project, current_user, create_package_file_params)
              .execute

            if response.error?
              bad_request!('Duplicate package is not allowed') if response.cause.package_file_already_exists?
              forbidden!('Package protected.') if response.cause.package_protected?
            end

            if params[:select] == 'package_file'
              present response[:package_file]
            else
              created!
            end
          rescue ObjectStorage::RemoteStoreError => e
            Gitlab::ErrorTracking.track_exception(e, extra: { file_name: params[:file_name], project_id: project.id })

            forbidden!
          end

          desc 'Download package file' do
            detail 'This feature was introduced in GitLab 13.5'
            success code: 200
            failure [
              { code: 401, message: 'Unauthorized' },
              { code: 403, message: 'Forbidden' },
              { code: 404, message: 'Not Found' }
            ]
            tags %w[generic_packages]
          end

          params do
            requires :package_name, type: String, desc: 'Package name', regexp: Gitlab::Regex.generic_package_name_regex, file_path: true
            requires :package_version, type: String, desc: 'Package version', regexp: Gitlab::Regex.generic_package_version_regex
            optional :path, type: String, desc: 'File directory path', file_path: true
            requires :file_name, type: String, desc: 'Package file name', regexp: Gitlab::Regex.generic_package_file_name_regex, file_path: true
          end

          route_setting :authentication, job_token_allowed: %i[request basic_auth], basic_auth_personal_access_token: true, deploy_token_allowed: true
          route_setting :authorization, job_token_policies: :read_packages,
            allow_public_access_for_enabled_project_features: :package_registry

          get do
            project = authorized_user_project(action: :read_package)

            authorize_read_package!(project)
            authorize_job_token_policies!(project)

            package = ::Packages::Generic::PackageFinder.new(project).execute!(params[:package_name], params[:package_version])
            package_file = ::Packages::PackageFileFinder.new(package, encoded_file_name).execute!

            track_package_event('pull_package', :generic, project: project, namespace: project.namespace)

            present_package_file!(package_file, content_disposition: :attachment)
          end
        end
      end
    end

    helpers do
      include ::API::Helpers::PackagesHelpers
      include ::API::Helpers::Packages::BasicAuthHelpers

      def max_file_size_exceeded?
        authorized_user_project.actual_limits.exceeded?(:generic_packages_max_file_size, params[:file].size)
      end

      def authorize_workhorse_params
        project = authorized_user_project

        {
          subject: project,
          maximum_size: project.actual_limits.generic_packages_max_file_size,
          use_final_store_path: true
        }
      end

      def encoded_file_name
        file_name = [declared_params[:path], declared_params[:file_name]].compact.join('/')
        declared_params[:path].present? ? URI.encode_uri_component(file_name) : file_name
      end
    end
  end
end
