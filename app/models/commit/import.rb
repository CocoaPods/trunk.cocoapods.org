require 'cocoapods-core'
require 'rest'

require 'app/models/commit'
require 'app/models/owner'
require 'app/models/pod'

module Pod
  module TrunkApp
    class Commit
      class Import
        DATA_URL_TEMPLATE = "https://raw.githubusercontent.com/#{ENV['GH_REPO']}/%s/%s"
        PODSPEC_FILE_EXT_REGEX = /\.podspec(.json)?\z/

        attr_reader :committer_email
        attr_reader :committer_name

        def initialize(committer_email, committer_name)
          @committer_email = committer_email
          @committer_name  = committer_name
        end

        # For each changed file, get its data (if it's a podspec).
        #
        def import(commit_sha, type, files)
          files.each do |file|
            next unless file =~ PODSPEC_FILE_EXT_REGEX

            pod_name, version_name = extract_name_and_version file

            pod = Pod.find_or_create(:name => pod_name)

            committer = find_or_create_committer

            if type == :removed
              handle_removed(pod, version_name, committer, commit_sha)
            else
              spec = fetch_spec(commit_sha, file)

              next unless spec

              pod.add_owner(committer) if pod.was_created?

              handle_with_existing_spec(type, spec, pod, committer, commit_sha)
            end
          end
        end

        # Extracts the pod name and the version name from the file name.
        #
        def extract_name_and_version(file_name)
          _, name, version_name, = *file_name.
            match(%r{([^\/]+)\/([^\/]+)\/[^\.]+#{PODSPEC_FILE_EXT_REGEX}})

          [name, version_name]
        end

        # Create a committer if needed.
        #
        def find_or_create_committer
          committer = Owner.find_by_email(committer_email)
          committer ||= Owner.create(:email => committer_email, :name => committer_name)
          committer
        end

        # If a commit is added or modified, the spec for it can be downloaded.
        #
        def handle_with_existing_spec(type, spec, pod, committer, commit_sha)
          send(:"handle_#{type}", spec, pod, committer, commit_sha)
        end

        # We add a commit to the pod's version and, if necessary, add a new version.
        #
        def handle_modified(spec, pod, committer, commit_sha)
          version = PodVersion.find_or_create(:pod => pod, :name => spec.version.to_s)
          if version.was_created?
            if pod.was_created?
              message = "Pod `#{pod.name}' and version `#{version.name}' created via Github hook."
            else
              message = "Version `#{version.description}' created via Github hook."
            end
            log_github_hook_call(version, message, committer)
          end

          commit = first_or_add_commit(version, commit_sha, spec, committer)
          version.update(:deleted => false)

          # TODO: add test for returning commit
          commit
        end

        # We only check if we have a commit for this pod and version and,
        # if not, add it.
        #
        def handle_added(spec, pod, committer, commit_sha)
          version = pod.versions_dataset.first(:name => spec.version.to_s)
          unless version && version.commits_dataset.first(:sha => commit_sha)
            handle_modified(spec, pod, committer, commit_sha)
          end
        end

        # If we have a version for the given pod and spec, we remove it.
        #
        # @param spec [Pod::Specification] The removed podspec.
        # @param pod [Pod] The removed version's pod.
        # @param committer [Owner] The committer.
        # @param commit_sha [String] The git commit SHA-1.
        #
        # TODO: Needs logging (an informative log message on version).
        #
        def handle_removed(pod, version_name, committer, commit_sha)
          if version = PodVersion.find(:pod => pod, :name => version_name)

            # Delete the version.
            log_deleted_version(version, committer)
            version.update(:deleted => true)

            # Delete a versionless pod.
            delete_versionless(pod)

            # Add the commit.
            first_or_add_commit(version, commit_sha, {}, committer)
          end
        end

        # Deletes the pod if it has no undeleted versions left.
        #
        def delete_versionless(pod)
          # Potentially delete the pod.
          undeleted_version_count = pod.versions.count { |version| !version.deleted? }
          if undeleted_version_count.zero?
            pod.update(:deleted => true)
          end
        end

        # Fetches the spec from GitHub.
        #
        # TODO: handle network/request failures
        #
        def fetch_spec(commit_sha, file)
          url = DATA_URL_TEMPLATE % [commit_sha, file]
          response = REST.get(url)
          data = response.body
          if response.ok?
            ::Pod::Specification.from_string(data, file)
          else
            log_failed_spec_fetch(url, response.status_code.to_s, data)
            nil
          end
        rescue REST::Error => e
          log_failed_spec_fetch(url, "#{e.class.name} - #{e.message}", e.backtrace.join("\n\t\t"))
          nil
        end

        # Either adds a commit or returns the first found.
        #
        def first_or_add_commit(version, commit_sha, spec, committer)
          version.commits_dataset.first(:sha => commit_sha) ||
            version.add_commit(
              :sha => commit_sha,
              :specification_data => JSON.pretty_generate(spec),
              :committer => committer,
              :imported => true,
            )
        end

        # Records a github hook call.
        #
        # @param version [PodVersion] The deleted version.
        # @param message [String] The message that is stored.
        # @param committer [Owner] The committer who enacted the deletion.
        #
        def log_github_hook_call(version, message, committer)
          version.add_log_message(
            :reference => "Github hook call to temporary ID: #{object_id}",
            :level => :warning,
            :message => message,
            :owner => committer,
          )
        end

        # Records a successfully deleted version.
        #
        # @param version [PodVersion] The deleted version.
        # @param committer [Owner] The committer who enacted the deletion.
        #
        def log_deleted_version(version, committer)
          LogMessage.create(
            :message => "Version `#{version.description}' deleted via Github hook.",
            :level => :warning,
            :owner => committer,
          )
        end

        # Records a failure when fetching a spec.
        #
        def log_failed_spec_fetch(url, message, data)
          LogMessage.create(
            :message => "There was an issue fetching the spec at #{url}: #{message}",
            :level => :error,
            :data => data,
          )
        end
      end
    end
  end
end
