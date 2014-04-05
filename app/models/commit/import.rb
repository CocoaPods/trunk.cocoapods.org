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
        def self.import(commit_sha, committer_email, type, files)
          files.each do |file|
            # TODO: Add .podspec example.
            #
            next unless file =~ /\.podspec(.json)?\z/

            spec = fetch_spec(commit_sha, file)
            pod = Pod.find(:name => spec.name)
            # TODO: add pod if it doesn't exist yet
            unless pod
              pod = Pod.create(:name => spec.name)
            end

            send(:"handle_#{type}", spec, pod, commit_sha, committer_email)
          end
        end

        # We add a commit to the pod's version and, if necessary, add a new version.
        #
        # rubocop:disable MethodLength
        def self.handle_modified(spec, pod, commit_sha, committer_email)
          # TODO: Always add the committer to the DB!
          # committer = pod.owners_dataset.first(:email => committer_email) #|| Owner.unclaimed
          committer = Owner.find_by_email(committer_email)
          unless committer
            committer = Owner.create(:email => committer_email, :name => 'TODO')
          end

          version_name = spec.version.to_s

          # Note: Sadly, we cannot use find_or_create here.
          #
          version = PodVersion.find(:pod => pod, :name => version_name)
          unless version
            version = PodVersion.create(:pod => pod, :name => version_name)
            version.add_log_message(
              :reference => "Github hook call to temporary ID: #{object_id}",
              :level => :warning,
              :message => "Version `#{version.description}' created via Github hook.",
              :owner => committer
            )
          end

          # TODO: test
          if version.commits_dataset.first(:sha => commit_sha)
            return
          end

          # Add a new commit to the existing version.
          #
          version.add_commit(
            :sha => commit_sha,
            :specification_data => JSON.pretty_generate(spec),
            :committer => committer
          )
        end
        # rubocop:enable MethodLength

        # We only check if we have it and, if not, add it.
        #
        def self.handle_added(spec, pod, commit_sha, committer_email)
          if commit = Commit.find(:sha => commit_sha)
            unless commit.pod_version.pod == pod
              # TODO: The existing commit in the BD is not about this pod. Log as error?
            end
          else
            # No? We should create it and connect it to the pod.
            #
            # TODO: What if the version does not exist yet? Should we add one?
            #
            handle_modified(spec, pod, commit_sha, committer_email)
          end
        end
      end
    end
  end
end
