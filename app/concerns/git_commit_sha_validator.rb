module Pod
  module TrunkApp
    module Concerns
      module GitCommitSHAValidator
        GIT_COMMIT_SHA_LENGTH = 40

        def validates_git_commit_sha(attr)
          validates_format /[0-9a-f]{#{GIT_COMMIT_SHA_LENGTH}}/, attr, :allow_nil => true
        end
      end
    end
  end
end
