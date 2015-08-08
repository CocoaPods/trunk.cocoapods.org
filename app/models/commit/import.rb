require 'cocoapods-core'
require 'rest'

require 'app/models/commit'
require 'app/models/owner'
require 'app/models/pod'

module Pod
  module TrunkApp
    class Commit
      module Import
        DATA_URL_TEMPLATE = "https://raw.githubusercontent.com/#{ENV['GH_REPO']}/%s/%s"

        def self.log_failed_spec_fetch(url, message, data)
          LogMessage.create(
            :message => "There was an issue fetching the spec at #{url}: #{message}",
            :level => :error,
            :data => data
          )
        end

        # TODO: handle network/request failures
        #
        def self.fetch_spec(commit_sha, file)
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

        # For each changed file, get its data (if it's a podspec).
        #
        def self.import(commit_sha, type, files, committer_email, committer_name)
          files.each do |file|
            next unless file =~ /\.podspec(.json)?\z/

            spec = fetch_spec(commit_sha, file)
            next unless spec

            unless committer = Owner.find_by_email(committer_email)
              committer = Owner.create(:email => committer_email, :name => committer_name)
            end

            pod = Pod.find_or_create(:name => spec.name)
            
            # TODO Move this into handle_added ?
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

          # TODO: add test for returning commit
          version.commits_dataset.first(:sha => commit_sha) || version.add_commit(
            :sha => commit_sha,
            :specification_data => JSON.pretty_generate(spec),
            :committer => committer,
            :imported => true
          )
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

        # If we have a version for the given pod and spec, we remove it.
        #
        # @param spec [Pod::Specification] The removed podspec.
        # @param pod [Pod] The removed version's pod.
        # @param committer [Owner] The committer.
        # @param _commit_sha [String] The git commit SHA-1. Not used.
        #
        def self.handle_removed(spec, pod, committer, _commit_sha)
          if version = PodVersion.find(:pod => pod, :name => spec.version.to_s)
            LogMessage.create(
              :message => "Version `#{version.description}' deleted via Github hook.",
              :level => :warning,
              :owner => committer
            )
            version.commits_dataset.delete
            version.delete
          end
        end
      end
    end
  end
end
