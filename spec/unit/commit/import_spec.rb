require File.expand_path('../../../spec_helper', __FILE__)

module Pod::TrunkApp
  describe Commit::Import, 'when importing' do
    def instance
      Commit::Import.new('test.user@example.com', 'Test User')
    end

    def trigger_commit_with_fake_data(type, files = ['Specs/KFData/1.0.1/KFData.podspec.json'])
      instance.import(
        '3cc2186863fb4d8a0fd4ffd82bc0ffe88499bd5f',
        type,
        files,
      )
    end

    describe '#extract_name_and_version' do
      it 'handles a normal example' do
        name, version_name = instance.
          extract_name_and_version('Specs/KFData/1.0.1/KFData.podspec.json')

        name.should == 'KFData'
        version_name.should == '1.0.1'
      end
      it 'handles an example without Specs' do
        name, version_name = instance.
          extract_name_and_version('KFData/1.0.1/KFData.podspec.json')

        name.should == 'KFData'
        version_name.should == '1.0.1'
      end
    end

    it 'gets the podspec data from the right URL' do
      expected_url = "https://raw.githubusercontent.com/#{ENV['GH_REPO']}/" \
        '3cc2186863fb4d8a0fd4ffd82bc0ffe88499bd5f/Specs/KFData/1.0.1/KFData.podspec.json'
      REST.expects(:get).with(expected_url).once.
        returns(rest_response('GitHub/ABContactHelper.podspec.json'))

      trigger_commit_with_fake_data(:added)
    end

    it 'processes payload data and creates a new pod (if one does not exist)' do
      REST.stubs(:get).returns(rest_response('GitHub/ABContactHelper.podspec.json'))

      lambda do
        trigger_commit_with_fake_data(
          :added,
          ['ABContactHelper/0.1/ABContactHelper.podspec.json'])
      end.should.change { Pod.count }

      pod = Pod.find(:name => 'ABContactHelper')
      pod.should.not.be.nil

      # Did log a big fat warning.
      #
      last_version = pod.versions.last
      last_log_message = last_version.log_messages.last
      last_log_message.pod_version.should == last_version
      last_log_message.message.should == "Pod `ABContactHelper' and version `0.1' created via Github hook."
    end

    it 'creates a LogMessage if no spec is fetched' do
      REST.stubs(:get).returns(rest_response('Bad Request', 400))
      sha = '3cc2186863fb4d8a0fd4ffd82bc0ffe88499bd5f'
      path = 'KFData/1.0.1/KFData.podspec.json'
      lambda do
        spec = instance.fetch_spec(sha, path)
        spec.should.be.nil?
      end.should.change { LogMessage.count }
      log_message = LogMessage.last
      log_message.level.should == :error
      log_message.message.should.match /(#{sha})*(#{path})*(400)/
      log_message.data.should == 'Bad Request'
    end

    it 'creates a LogMessage the request raises' do
      error = Timeout::Error.new('execution expired')
      REST.stubs(:get).raises(error)
      sha = '3cc2186863fb4d8a0fd4ffd82bc0ffe88499bd5f'
      path = 'KFData/1.0.1/KFData.podspec.json'
      lambda do
        spec = instance.fetch_spec(sha, path)
        spec.should.be.nil?
      end.should.change { LogMessage.count }
      log_message = LogMessage.last
      log_message.level.should == :error
      log_message.message.should.match /(#{sha})*(#{path})*(Timeout::Error - execution expired)/
      log_message.data.should == error.backtrace.join("\n\t\t")
    end

    # Create existing pod.
    #
    before do
      @existing_spec = ::Pod::Specification.from_json(fixture_read('GitHub/KFData.podspec.json'))
      @existing_pod = Pod.create(:name => @existing_spec.name)
    end

    it 'does add the add commit and a version if missing and version does not exist' do
      REST.stubs(:get).returns(rest_response('GitHub/KFData.podspec.json'))
      trigger_commit_with_fake_data(:added)

      # Did log a big fat warning.
      #
      last_version = @existing_pod.reload.versions.last
      last_log_message = last_version.log_messages.last
      last_log_message.pod_version.should == last_version
      last_log_message.message.should == "Version `KFData 1.0.1' created via Github hook."

      commit = last_version.last_published_by
      commit.sha.should == '3cc2186863fb4d8a0fd4ffd82bc0ffe88499bd5f'
    end

    it 'marks a commit as being imported' do
      REST.stubs(:get).returns(rest_response('GitHub/KFData.podspec.json'))
      trigger_commit_with_fake_data(:modified)
      last_version = @existing_pod.reload.versions.last
      commit = last_version.last_published_by
      commit.should.be.imported
    end

    # Create existing pod version
    #
    before do
      @existing_version = PodVersion.create(:pod => @existing_pod, :name => @existing_spec.version.version)
    end

    it 'processes payload data and adds a new version, logs warning and commit (if the pod version does not exist)' do
      REST.stubs(:get).returns(rest_response('GitHub/KFData.podspec.new.json'))

      trigger_commit_with_fake_data(:modified)

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
      REST.stubs(:get).returns(rest_response(fixture_read('GitHub/KFData.podspec.json')))
    end

    it 'processes payload data and creates a new submission job (because the version exists)' do
      trigger_commit_with_fake_data(:modified)

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
        trigger_commit_with_fake_data(:modified)
      end.should.not.change { Owner.count }

      commit = @existing_pod.reload.versions.last.last_published_by
      commit.committer.should == committer
    end

    it 'does not update the committer name if the committer existed' do
      committer = Owner.create(:email => 'test.user@example.com', :name => 'Test User')

      trigger_commit_with_fake_data(:modified)

      committer.reload.name.should == 'Test User'
    end

    it 'adds a new committer to the commit' do
      lambda do
        trigger_commit_with_fake_data(:modified)
      end.should.change { Owner.count }

      committer = Owner.first(:email => 'test.user@example.com')
      committer.name.should == 'Test User'

      commit = @existing_pod.reload.versions.last.last_published_by
      commit.committer.should == committer
    end

    it 'sets the committer as the pod owner if the pod was newly created' do
      # Reset
      @existing_version.delete
      @existing_pod.delete

      trigger_commit_with_fake_data(:added)

      Pod.find(:name => 'KFData').owners.map(&:email).should == ['test.user@example.com']
    end

    it 'does *not* set the committer as the pod owner if the pod already existed' do
      trigger_commit_with_fake_data(:added)

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
        trigger_commit_with_fake_data(:added)
      end.should.change { Commit.count }

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

      trigger_commit_with_fake_data(:modified)
    end

    it 'marks removed pod versions as deleted' do
      pod = Pod.create(:name => 'Intercom')
      PodVersion.create(:pod => pod, :name => '1.1.6')
      PodVersion.create(:pod => pod, :name => '1.1.8')
      undeleted = PodVersion.create(:pod => pod, :name => '2.0.0')

      REST.stubs(:get).returns(rest_response('GitHub/Intercom.podspec.remove.json'))

      instance.import(
        'c1947f722b29c919cb8bcd16f5db27866ae2ce09',
        :removed,
        %w(Specs/Intercom/1.1.6/Intercom.podspec.json Specs/Intercom/1.1.8/Intercom.podspec.json),
      )

      pod.versions_dataset.all.reject(&:deleted?).should == [undeleted]
      pod.versions_dataset.all.select(&:deleted?).map(&:name).should == %w(1.1.6 1.1.8)
    end

    it 'marks pods as deleted when all versions are deleted' do
      pod = Pod.create(:name => 'Intercom')
      PodVersion.create(:pod => pod, :name => '1.1.6')
      PodVersion.create(:pod => pod, :name => '1.1.8')

      REST.stubs(:get).returns(rest_response('GitHub/Intercom.podspec.remove.json'))

      # Assert pod is not deleted.
      pod.reload.deleted.should == false

      instance.import(
        'c1947f722b29c919cb8bcd16f5db27866ae2ce09',
        :removed,
        %w(Specs/Intercom/1.1.6/Intercom.podspec.json Specs/Intercom/1.1.8/Intercom.podspec.json),
      )

      # Assert all versions are deleted.
      pod.versions_dataset.all.reject(&:deleted?).should == []

      pod.reload.deleted.should == true
    end
  end
end
