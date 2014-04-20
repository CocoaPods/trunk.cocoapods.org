require 'cocoapods-core'
require 'rest'

require 'app/models/commit'
require 'app/models/owner'
require 'app/models/pod'

module Pod
  module TrunkApp
    class Commit
      module Import
        # TODO: Point to correct repo
        #
        DATA_URL_TEMPLATE = 'https://raw.github.com/alloy/trunk.cocoapods.org-test/%s/Specs/%s'

        # TODO: handle network/request failures
        #
        def self.fetch_spec(commit_sha, file)
          data = REST.get(DATA_URL_TEMPLATE % [commit_sha, file]).body
          ::Pod::Specification.from_string(data, file)
        end

        # For each changed file, get its data (if it's a podspec).
        #
        # TODO: Only get the latest version of a file.
        #
        def self.import(commit_sha, type, files, committer_email, committer_name)
          files.each do |file|
            next unless file =~ /\.podspec(.json)?\z/

            spec = fetch_spec(commit_sha, file)

            unless committer = Owner.find_by_email(committer_email)
              committer = Owner.create(:email => committer_email, :name => committer_name)
            end

            pod = Pod.find_or_create(:name => spec.name)
            pod.add_owner(committer) if pod.was_created?

            send(:"handle_#{type}", spec, pod, committer, commit_sha)
          end
        end

        # We add a commit to the pod's version and, if necessary, add a new version.
        #
        def self.handle_modified(spec, pod, committer, commit_sha)
          version = PodVersion.find_or_create(:pod => pod, :name => spec.version.to_s)
          if version.was_created?
            if pod.was_created?
              message = "Pod `#{pod.name}' and version `#{version.name}' created via Github hook."
            else
              message = "Version `#{version.description}' created via Github hook."
            end
            version.add_log_message(
              :reference => "Github hook call to temporary ID: #{object_id}",
              :level => :warning,
              :message => message,
              :owner => committer
            )
          end

          # Check if an associated Commit for this sha exists yet.
          unless version.commits_dataset.first(:sha => commit_sha)
            version.add_commit(
              :sha => commit_sha,
              :specification_data => JSON.pretty_generate(spec),
              :committer => committer
            )
          end
        end

        # We only check if we have a commit for this pod and version and,
        # if not, add it.
        #
        def self.handle_added(spec, pod, committer, commit_sha)
          version = pod.versions_dataset.first(:name => spec.version.to_s)
          unless version && version.commits_dataset.first(:sha => commit_sha)
            handle_modified(spec, pod, committer, commit_sha)
          end
        end
      end
    end
  end
end
