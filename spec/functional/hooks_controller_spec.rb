require File.expand_path('../../spec_helper', __FILE__)

module Pod::TrunkApp
  describe HooksController, 'when receiving push updates from the repository' do

    def post_raw_hook_json_data
      header 'Content-Type', 'application/x-www-form-urlencoded'
      payload = fixture_read('GitHub/post_receive_hook_json_data.raw')
      post '/github-post-receive/', payload
    end

    def post_raw_hook_ruby_data
      header 'Content-Type', 'application/x-www-form-urlencoded'
      payload = fixture_read('GitHub/post_receive_hook_ruby_data.raw')
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

    rest_response = Struct.new(:body)

    # JSON podspecs
    #

    it 'processes payload data but does not create a new pod (if one does not exist)' do
      REST.stubs(:get).returns(rest_response.new(fixture_read('GitHub/ABContactHelper.podspec.json')))

      post_raw_hook_json_data

      last_response.status.should == 200

      Pod.find(:name => 'MobileAppTracker').should.be.nil
    end

    before do
      Owner.create(:email => Owner::UNCLAIMED_OWNER_EMAIL, :name => 'Unclaimed')
    end

    it 'processes payload data and adds a new version, logs warning and commit (if the pod version does not exist)' do
      # Create existing pod.
      #
      existing_spec = ::Pod::Specification.from_json(fixture_read('GitHub/KFData.podspec.json'))
      existing_pod = Pod.create(:name => existing_spec.name)
      PodVersion.create(:pod => existing_pod, :name => existing_spec.version.version)

      REST.stubs(:get).returns(rest_response.new(fixture_read('GitHub/KFData.podspec.new.json')))

      post_raw_hook_json_data

      last_response.status.should == 200

      pod = Pod.find(:name => 'KFData')

      # Did add a version.
      #
      pod.versions.map(&:name).should == ['1.0.1', '1.0.2']

      # Did log a big fat warning.
      #
      last_version = pod.versions.last
      last_log_message = last_version.log_messages.last
      last_log_message.pod_version.should == last_version
      last_log_message.message.should == "Version `KFData 1.0.2' created via Github hook."

      # Did add a new commit.
      #
      pod.versions.find { |version| version.name == '1.0.2' }.commits.map(&:sha).should == ['3cc2186863fb4d8a0fd4ffd82bc0ffe88499bd5f']
    end

    it 'processes payload data and creates a new submission job (because the version exists)' do
      # Create existing pod.
      #
      existing_spec = ::Pod::Specification.from_json(fixture_read('GitHub/KFData.podspec.json'))
      existing_pod = Pod.create(:name => existing_spec.name)
      PodVersion.create(:pod => existing_pod, :name => existing_spec.version.version)

      REST.stubs(:get).returns(rest_response.new(fixture_read('GitHub/KFData.podspec.json')))

      post_raw_hook_json_data

      last_response.status.should == 200

      pod = Pod.find(:name => 'KFData')

      # Did not add a new version.
      #
      pod.versions.map(&:name).should == ['1.0.1']

      # Did add a new commit.
      #
      commit = pod.versions.last.commits.last
      commit.committer.should == Owner.unclaimed
      commit.sha.should == '3cc2186863fb4d8a0fd4ffd82bc0ffe88499bd5f'
      commit.specification_data.should == fixture_read('GitHub/KFData.podspec.json')

      # Updated the version correctly.
      #
      version = pod.versions.last
      version.should.be.published
      version.commit_sha.should == '3cc2186863fb4d8a0fd4ffd82bc0ffe88499bd5f'
      version.last_published_by.should == commit
    end

    it 'adds the right committer to the commit' do
      # Create existing pod.
      #
      existing_spec = ::Pod::Specification.from_json(fixture_read('GitHub/KFData.podspec.json'))
      existing_pod = Pod.create(:name => existing_spec.name)
      PodVersion.create(:pod => existing_pod, :name => existing_spec.version.version)

      test_user = Owner.create(:email => 'test.user@example.com', :name => 'Test User')
      test_user.add_pod(existing_pod)

      REST.stubs(:get).returns(rest_response.new(fixture_read('GitHub/KFData.podspec.json')))

      post_raw_hook_json_data

      last_response.status.should == 200

      pod = Pod.find(:name => 'KFData')
      commit = pod.versions.last.last_published_by

      commit.committer.should == test_user
    end

    it 'adds the right committer to the commit' do
      # Create existing pod.
      #
      existing_spec = ::Pod::Specification.from_json(fixture_read('GitHub/KFData.podspec.json'))
      existing_pod = Pod.create(:name => existing_spec.name)
      PodVersion.create(:pod => existing_pod, :name => existing_spec.version.version)

      REST.stubs(:get).returns(rest_response.new(fixture_read('GitHub/KFData.podspec.json')))

      post_raw_hook_json_data

      last_response.status.should == 200

      pod = Pod.find(:name => 'KFData')

      commit = pod.versions.last.last_published_by

      commit.committer.should == Owner.unclaimed
    end

    it 'creates the add commit if missing and version exists' do
      # Create existing pod.
      #
      existing_spec = ::Pod::Specification.from_json(fixture_read('GitHub/KFData.podspec.json'))
      existing_pod = Pod.create(:name => existing_spec.name)
      pod_version = PodVersion.create(:pod => existing_pod, :name => existing_spec.version.version)

      pod = Pod.find(:name => 'KFData')
      commit = pod.versions.last.last_published_by

      commit.should.be.nil

      REST.stubs(:get).returns(rest_response.new(fixture_read('GitHub/KFData.podspec.json')))

      post_raw_hook_json_data

      last_response.status.should == 200

      pod = Pod.find(:name => 'KFData')
      commit = pod.versions.last.last_published_by

      commit.sha.should == '3cc2186863fb4d8a0fd4ffd82bc0ffe88499bd5f'
    end

    it 'does add the add commit and a version if missing and version does not exist' do
      # Create existing pod.
      #
      existing_spec = ::Pod::Specification.from_json(fixture_read('GitHub/KFData.podspec.json'))
      existing_pod = Pod.create(:name => existing_spec.name)

      pod = Pod.find(:name => 'KFData')
      pod.versions.last.should.be.nil

      REST.stubs(:get).returns(rest_response.new(fixture_read('GitHub/KFData.podspec.json')))

      post_raw_hook_json_data

      last_response.status.should == 200

      pod = Pod.find(:name => 'KFData')

      # Did log a big fat warning.
      #
      last_version = pod.versions.last
      last_log_message = last_version.log_messages.last
      last_log_message.pod_version.should == last_version
      last_log_message.message.should == "Version `KFData 1.0.1' created via Github hook."

      commit = last_version.last_published_by

      commit.sha.should == '3cc2186863fb4d8a0fd4ffd82bc0ffe88499bd5f'
    end

    # Ruby podspecs
    #

    it 'processes payload data but does not create a new pod (if one does not exist)' do
      REST.stubs(:get).returns(rest_response.new(fixture_read('GitHub/ABContactHelper.podspec')))

      post_raw_hook_ruby_data

      last_response.status.should == 200

      Pod.find(:name => 'MobileAppTracker').should.be.nil
    end

    it 'processes payload data and adds a new version, logs warning and commit (if the pod version does not exist)' do
      # Create existing pod.
      #
      file = 'GitHub/KFData.podspec'
      existing_spec = ::Pod::Specification.from_string(fixture_read(file), file)
      existing_pod = Pod.create(:name => existing_spec.name)
      PodVersion.create(:pod => existing_pod, :name => existing_spec.version.version)

      REST.stubs(:get).returns(rest_response.new(fixture_read('GitHub/KFData.new.podspec')))

      post_raw_hook_ruby_data

      last_response.status.should == 200

      pod = Pod.find(:name => 'KFData')

      # Did add a version.
      #
      pod.versions.map(&:name).should == ['1.0.1', '1.0.2']

      # Did log a big fat warning.
      #
      last_version = pod.versions.last
      last_log_message = last_version.log_messages.last
      last_log_message.pod_version.should == last_version
      last_log_message.message.should == "Version `KFData 1.0.2' created via Github hook."

      # Did add a new commit.
      #
      pod.versions.find { |version| version.name == '1.0.2' }.commits.map(&:sha).should == ['3cc2186863fb4d8a0fd4ffd82bc0ffe88499bd5f']
    end

    it 'processes payload data and creates a new submission job (because the version exists)' do
      # Create existing pod.
      #
      file = 'GitHub/KFData.podspec'
      existing_spec = ::Pod::Specification.from_string(fixture_read(file), file)
      existing_pod = Pod.create(:name => existing_spec.name)
      PodVersion.create(:pod => existing_pod, :name => existing_spec.version.version)

      REST.stubs(:get).returns(rest_response.new(fixture_read(file)))

      post_raw_hook_ruby_data

      last_response.status.should == 200

      pod = Pod.find(:name => 'KFData')

      # Did not add a new version.
      #
      pod.versions.map(&:name).should == ['1.0.1']

      # Did add a new commit.
      #
      commit = pod.versions.last.commits.last
      commit.committer.should == Owner.unclaimed
      commit.sha.should == '3cc2186863fb4d8a0fd4ffd82bc0ffe88499bd5f'
      commit.specification_data.should == fixture_read('GitHub/KFData.podspec.json') # Note: Specification data is in JSON.

      # Updated the version correctly.
      #
      version = pod.versions.last
      version.should.be.published
      version.commit_sha.should == '3cc2186863fb4d8a0fd4ffd82bc0ffe88499bd5f'
      version.last_published_by.should == commit
    end

    it 'adds the right committer to the commit' do
      # Create existing pod.
      #
      file = 'GitHub/KFData.podspec'
      existing_spec = ::Pod::Specification.from_string(fixture_read(file), file)
      existing_pod = Pod.create(:name => existing_spec.name)
      PodVersion.create(:pod => existing_pod, :name => existing_spec.version.version)

      test_user = Owner.create(:email => 'test.user@example.com', :name => 'Test User')
      test_user.add_pod(existing_pod)

      REST.stubs(:get).returns(rest_response.new(fixture_read(file)))

      post_raw_hook_ruby_data

      last_response.status.should == 200

      pod = Pod.find(:name => 'KFData')
      commit = pod.versions.last.last_published_by

      commit.committer.should == test_user
    end

    it 'adds the right committer to the commit' do
      # Create existing pod.
      #
      file = 'GitHub/KFData.podspec'
      existing_spec = ::Pod::Specification.from_string(fixture_read(file), file)
      existing_pod = Pod.create(:name => existing_spec.name)
      PodVersion.create(:pod => existing_pod, :name => existing_spec.version.version)

      REST.stubs(:get).returns(rest_response.new(fixture_read(file)))

      post_raw_hook_ruby_data

      last_response.status.should == 200

      pod = Pod.find(:name => 'KFData')

      commit = pod.versions.last.last_published_by

      commit.committer.should == Owner.unclaimed
    end

    it 'creates the add commit if missing and version exists' do
      # Create existing pod.
      #
      file = 'GitHub/KFData.podspec'
      existing_spec = ::Pod::Specification.from_string(fixture_read(file), file)
      existing_pod = Pod.create(:name => existing_spec.name)
      pod_version = PodVersion.create(:pod => existing_pod, :name => existing_spec.version.version)

      pod = Pod.find(:name => 'KFData')
      commit = pod.versions.last.last_published_by

      commit.should.be.nil

      REST.stubs(:get).returns(rest_response.new(fixture_read(file)))

      post_raw_hook_ruby_data

      last_response.status.should == 200

      pod = Pod.find(:name => 'KFData')
      commit = pod.versions.last.last_published_by

      commit.sha.should == '3cc2186863fb4d8a0fd4ffd82bc0ffe88499bd5f'
    end

    it 'does add the add commit and a version if missing and version does not exist' do
      # Create existing pod.
      #
      file = 'GitHub/KFData.podspec'
      existing_spec = ::Pod::Specification.from_string(fixture_read(file), file)
      existing_pod = Pod.create(:name => existing_spec.name)

      pod = Pod.find(:name => 'KFData')
      pod.versions.last.should.be.nil

      REST.stubs(:get).returns(rest_response.new(fixture_read('GitHub/KFData.podspec')))

      post_raw_hook_ruby_data

      last_response.status.should == 200

      pod = Pod.find(:name => 'KFData')

      # Did log a big fat warning.
      #
      last_version = pod.versions.last
      last_log_message = last_version.log_messages.last
      last_log_message.pod_version.should == last_version
      last_log_message.message.should == "Version `KFData 1.0.1' created via Github hook."

      commit = last_version.last_published_by

      commit.sha.should == '3cc2186863fb4d8a0fd4ffd82bc0ffe88499bd5f'
    end

  end
end
