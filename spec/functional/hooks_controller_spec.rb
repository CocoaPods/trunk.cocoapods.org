require File.expand_path('../../spec_helper', __FILE__)

module Pod::TrunkApp
  describe HooksController, 'when receiving push updates from the repository' do
    def post_raw_hook_json_data
      header 'Content-Type', 'application/x-www-form-urlencoded'
      payload = fixture_read('GitHub/post_receive_hook_json_data.raw')
      post '/github-post-receive/', payload
    end

    def post_raw_merge_commit_hook_json_data
      header 'Content-Type', 'application/x-www-form-urlencoded'
      payload = fixture_read('GitHub/post_receive_hook_json_data_merge_commit.raw')
      post '/github-post-receive/', payload
    end

    def post_raw_merge_commit_hook_non_json_data
      header 'Content-Type', 'application/x-www-form-urlencoded'
      payload = fixture_read('GitHub/post_receive_hook_non_json_data_merge_commit.raw')
      post '/github-post-receive/', payload
    end

    before do
      header 'X-Github-Delivery', '37ac017e-902c-11e3-8115-655d22cdc2ab'
      header 'User-Agent', 'GitHub Hookshot 7e04da1'
      header 'Content-Length', '3687'
      header 'X-Request-Id', '00f5fba2-c1ef-4169-b417-8abf02b26b94'
      header 'Connection', 'close'
      header 'X-Github-Event', 'push'
      header 'Accept', '*/*'
      header 'Host', 'trunk.cocoapods.org'
    end

    it 'fails with media type other than JSON data' do
      header 'Content-Type', 'text/yaml'
      post '/github-post-receive/', ''
      last_response.status.should == 415
    end

    it 'fails with data other than a push payload' do
      header 'Content-Type', 'application/x-www-form-urlencoded'
      post '/github-post-receive/', :something => 'else'
      last_response.status.should == 422
    end

    it 'fails with a payload other than serialized push data' do
      header 'Content-Type', 'application/x-www-form-urlencoded'
      post '/github-post-receive/', :payload => 'not-push-data'
      last_response.status.should == 415
    end

    it 'processes payload data and creates a new pod (if one does not exist)' do
      pod = Pod.find(:name => 'KFData')
      pod.should.be.nil

      REST.stubs(:get).returns(rest_response('GitHub/KFData.podspec.json'))
      lambda do
        post_raw_hook_json_data
      end.should.change { Pod.count }
      last_response.status.should == 200

      pod = Pod.find(:name => 'KFData')
      pod.should.not.be.nil

      # Did log a big fat warning.
      #
      last_version = pod.versions.last
      last_log_message = last_version.log_messages.last
      last_log_message.pod_version.should == last_version
      last_log_message.message.should == "Pod `KFData' and version `1.0.1' created via Github hook."
    end

    # Create existing pod.
    #
    before do
      @existing_spec = ::Pod::Specification.from_json(fixture_read('GitHub/KFData.podspec.json'))
      @existing_pod = Pod.create(:name => @existing_spec.name)
    end

    it 'does add the add commit and a version if missing and version does not exist' do
      REST.stubs(:get).returns(rest_response('GitHub/KFData.podspec.json'))
      post_raw_hook_json_data
      last_response.status.should == 200

      # Did log a big fat warning.
      #
      last_version = @existing_pod.reload.versions.last
      last_log_message = last_version.log_messages.last
      last_log_message.pod_version.should == last_version
      last_log_message.message.should == "Version `KFData 1.0.1' created via Github hook."

      commit = last_version.last_published_by
      commit.sha.should == '3cc2186863fb4d8a0fd4ffd82bc0ffe88499bd5f'
    end

    # Create existing pod version.
    #
    before do
      @existing_version = PodVersion.create(:pod => @existing_pod, :name => @existing_spec.version.version)
    end

    it 'processes payload data and adds a new version, logs warning and commit (if the pod version does not exist)' do
      REST.stubs(:get).returns(rest_response('GitHub/KFData.podspec.new.json'))
      post_raw_hook_json_data
      last_response.status.should == 200
      @existing_pod.reload

      # Did add a version.
      #
      @existing_pod.versions.map(&:name).should == ['1.0.1', '1.0.2']

      # Did log a big fat warning.
      #
      last_version = @existing_pod.versions.last
      last_log_message = last_version.log_messages.last
      last_log_message.pod_version.should == last_version
      last_log_message.message.should == "Version `KFData 1.0.2' created via Github hook."

      # Did add a new commit.
      #
      version = @existing_pod.versions.find { |pod_version| pod_version.name == '1.0.2' }
      shas = version.commits.map(&:sha)
      shas.should == ['3cc2186863fb4d8a0fd4ffd82bc0ffe88499bd5f']
    end

    # Stub data for the existing pod version
    #
    before do
      REST.stubs(:get).returns(rest_response('GitHub/KFData.podspec.json'))
    end

    it 'processes payload data and creates a new submission job (because the version exists)' do
      post_raw_hook_json_data
      last_response.status.should == 200
      @existing_pod.reload

      # Did not add a new version.
      #
      @existing_pod.versions.map(&:name).should == ['1.0.1']

      # Did add a new commit.
      #
      commit = @existing_pod.versions.last.commits.last
      commit.committer.should == Owner.first(:email => 'test.user@example.com') # Owner.unclaimed
      commit.sha.should == '3cc2186863fb4d8a0fd4ffd82bc0ffe88499bd5f'
      commit.specification_data.should == fixture_read('GitHub/KFData.podspec.json')

      # Updated the version correctly.
      #
      version = @existing_pod.versions.last
      version.should.be.published
      version.commit_sha.should == '3cc2186863fb4d8a0fd4ffd82bc0ffe88499bd5f'
      version.last_published_by.should == commit
    end

    it 'adds an existing committer to the commit' do
      committer = Owner.create(:email => 'test.user@example.com', :name => 'Test User')

      lambda do
        post_raw_hook_json_data
      end.should.not.change { Owner.count }
      last_response.status.should == 200

      commit = @existing_pod.reload.versions.last.last_published_by
      commit.committer.should == committer
    end

    it 'does not update the committer name if the committer existed' do
      committer = Owner.create(:email => 'test.user@example.com', :name => 'Test User')
      post_raw_hook_json_data
      last_response.status.should == 200
      committer.reload.name.should == 'Test User'
    end

    it 'adds a new committer to the commit' do
      lambda do
        post_raw_hook_json_data
      end.should.change { Owner.count }
      last_response.status.should == 200

      committer = Owner.first(:email => 'test.user@example.com')
      committer.name.should == 'Test User'

      commit = @existing_pod.reload.versions.last.last_published_by
      commit.committer.should == committer
    end

    it 'sets the committer as the pod owner if the pod was newly created' do
      # Reset
      @existing_version.delete
      @existing_pod.delete

      post_raw_hook_json_data
      last_response.status.should == 200

      Pod.find(:name => 'KFData').owners.map(&:email).should == ['test.user@example.com']
    end

    it 'does *not* set the committer as the pod owner if the pod already existed' do
      post_raw_hook_json_data
      last_response.status.should == 200
      @existing_pod.reload.owners.map(&:email).should.not.include 'test.user@example.com'
    end

    it 'creates the add commit if missing for this pod and version exists' do
      other_pod = Pod.create(:name => 'ObjectiveSugar')
      other_version = other_pod.add_version(:name => '1.0.0')
      other_committer = Owner.create(:email => 'other@example.com', :name => 'Other Committer')
      other_version.add_commit(
        :sha => '3cc2186863fb4d8a0fd4ffd82bc0ffe88499bd5f',
        :specification_data => 'DATA',
        :committer => other_committer,
      )

      lambda do
        post_raw_hook_json_data
      end.should.change { Commit.count }
      last_response.status.should == 200

      commit = @existing_pod.reload.versions.last.last_published_by
      commit.sha.should == '3cc2186863fb4d8a0fd4ffd82bc0ffe88499bd5f'
    end

    it 'does not try to add a commit to a version if a commit already exists' do
      committer = Owner.create(:email => 'test.user@example.com', :name => 'Test User')
      version = PodVersion.create(:pod => @existing_pod, :name => '1.0.2')
      commit = version.add_commit(
        :sha => '3cc2186863fb4d8a0fd4ffd82bc0ffe88499bd5f',
        :specification_data => 'DATA',
        :committer => committer,
      )

      PodVersion.any_instance.expects(:add_commit).never

      REST.stubs(:get).returns(rest_response('GitHub/KFData.podspec.new.json'))
      post_raw_hook_json_data
    end

    it 'does not process the merge commit - only the merged commit' do
      Commit::Import.any_instance.expects(:import).
        with(
          'a919e8abd40ea9b8f2e4cdd38d58966b92aba94c',
          :added,
          ['PromiseKit/0.9.0/PromiseKit.podspec.json'],
        ).once

      post_raw_merge_commit_hook_json_data
    end

    it 'does not process a commit file which does not end in .json' do
      Commit::Import.any_instance.expects(:import).never

      post_raw_merge_commit_hook_non_json_data
    end
  end
end
