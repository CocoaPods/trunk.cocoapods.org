require File.expand_path('../../../spec_helper', __FILE__)
require 'app/controllers/api/pods_controller'
require 'cocoapods-core'

module SpecHelpers::PodsController
  include SpecHelpers::CommitResponse

  def self.extended(context)
    context.send(:extend, SpecHelpers::Authentication)
    context.send(:extend, SpecHelpers::Response)
    context.before do
      header 'Content-Type', 'application/json; charset=utf-8'
      @spec = @pod = @version = @job = @owner = nil
    end
  end

  def spec
    @spec ||= fixture_specification('AFNetworking.podspec')
  end

  def valid_commit_attrs
    {
      :committer => @owner,
      :sha => '3ca23060197547eef92983f15590b5a87270615f',
      :specification_data => 'DATA',
    }
  end

  def create_pod_version!
    @pod = Pod::TrunkApp::Pod.create(:name => spec.name)
    @pod.add_owner(@owner) if @owner
    @version = @pod.add_version(:name => spec.version.to_s)
  end
end

module Pod::TrunkApp
  describe PodsController, 'when POSTing pod versions with an authenticated owner' do
    extend SpecHelpers::PodsController

    before do
      response = response(201, { :commit => { :sha => '3ca23060197547eef92983f15590b5a87270615f' } }.to_json)
      PushJob.any_instance.stubs(:push!).returns(response)
      SpecificationWrapper.any_instance.stubs(:publicly_accessible?).returns(true)

      sign_in!
    end

    seed_unclaimed

    it 'only accepts JSON' do
      header 'Content-Type', 'text/yaml'
      post '/', {}, 'HTTPS' => 'on'
      last_response.status.should == 415
    end

    it 'does not accept a push unless explicitely enabled' do
      begin
        [nil, '', 'false'].each do |value|
          ENV['TRUNK_APP_PUSH_ALLOWED'] = value
          lambda do
            post '/', spec.to_json
          end.should.not.change { Pod.count + PodVersion.count }
          last_response.status.should == 503
          json_response['error'].should.match /We have closed pushing to CocoaPods trunk/
        end
      ensure
        ENV['TRUNK_APP_PUSH_ALLOWED'] = 'true'
      end
    end

    it 'allows a specific user through when explicitely disabled' do
      ENV['TRUNK_APP_PUSH_ALLOWED'] = 'false'
      ENV['TRUNK_PUSH_ALLOW_OWNER_ID'] = @owner.id.to_s

      post '/', spec.to_json
      last_response.status.should == 302
      last_response.location.should == 'https://example.org/AFNetworking/versions/1.2.0'

      ENV['TRUNK_APP_PUSH_ALLOWED'] = 'true'
      ENV['TRUNK_PUSH_ALLOW_OWNER_ID'] = nil
    end

    it 'fails with data other than serialized spec data' do
      lambda do
        post '/', ''
      end.should.not.change { Pod.count + PodVersion.count }
      last_response.status.should == 400

      lambda do
        post '/', '{"something":"else"}'
      end.should.not.change { Pod.count + PodVersion.count }
      last_response.status.should == 422
    end

    it 'fails when the client CocoaPods version is lower than the minimum' do
      lambda do
        post '/', spec.to_json, 'User-Agent' => 'CocoaPods/0.1.0.pre.1'
      end.should.not.change { Pod.count + PodVersion.count }

      last_response.status.should == 422
      json_response['error'].should.match /minimum CocoaPods version/
    end

    it 'fails with a spec that does not pass a quick lint' do
      spec.name = nil
      spec.version = nil
      spec.license = nil

      lambda do
        post '/', spec.to_json
      end.should.not.change { Pod.count + PodVersion.count }

      last_response.status.should == 422
      json_response.should == {
        'error' => 'The Pod Specification did not pass validation.',
        'data' => {
          'errors'   => ['Missing required attribute `name`.', 'A version is required.'],
          'warnings' => ['Missing required attribute `license`.', 'Missing license type.'],
        },
      }
    end

    it 'succeeds with a spec that has the pushed_with_swift_version attribute' do
      lambda do
        lambda do
          post '/', JSON.load(spec.to_json).update('pushed_with_swift_version' => '3.0').to_json
        end.should.change { Pod.count }
      end.should.change { PodVersion.count }
      last_response.status.should == 302
      last_response.location.should == 'https://example.org/AFNetworking/versions/1.2.0'
      Pod.first(:name => spec.name).versions.map(&:name).should == [spec.version.to_s]
    end

    it 'succeeds with a spec that has warnings when allow warnings has been specified' do
      spec.license = nil

      lambda do
        lambda do
          post '/?allow_warnings=true', spec.to_json
        end.should.change { Pod.count }
      end.should.change { PodVersion.count }
      last_response.status.should == 302
      last_response.location.should == 'https://example.org/AFNetworking/versions/1.2.0'
      Pod.first(:name => spec.name).versions.map(&:name).should == [spec.version.to_s]
    end

    it 'does not allow a push for an existing pod with different case' do
      @owner.add_pod(:name => spec.name.upcase)
      lambda do
        post '/', spec.to_json
      end.should.not.change { Pod.count }
      last_response.status.should == 422
      json_response.should == { 'error' => { 'name' => ['is already taken'] } }
    end

    it 'allows an existing owner to push a new version when the pod is deleted' do
      @owner.add_pod(:name => spec.name).update(:deleted => true)
      lambda do
        post '/', spec.to_json
      end.should.change { PodVersion.count }
      last_response.status.should == 302
      Pod.find_by_name(spec.name).should.not.be.deleted
    end

    it 'does not allow a non-owner to push a new version' do
      @pod = Pod.create(:name => spec.name)
      @pod.add_owner(Owner.create(:email => 'someone@example.com', :name => 'Someone Else'))

      lambda do
        post '/', spec.to_json
      end.should.not.change { [PodVersion.count, @pod.owners] }

      last_response.status.should == 403
      JSON.load(last_response.body).should == {
        'error' => 'You (appie@example.com) are not allowed to push new versions for this pod. ' \
                   'The owners of this pod are someone@example.com.',
      }
    end

    it "does not allow a push for an existing pod version if it's published" do
      @owner.add_pod(:name => spec.name).
        add_version(:name => spec.version.to_s).
        add_commit(valid_commit_attrs)
      lambda do
        post '/', spec.to_json
      end.should.not.change { Pod.count + PodVersion.count }
      last_response.status.should == 409
      last_response.location.should == 'https://example.org/AFNetworking/versions/1.2.0'
    end

    it 'creates new pod and version records, then redirects' do
      lambda do
        lambda do
          post '/', spec.to_json
        end.should.change { Pod.count }
      end.should.change { PodVersion.count }
      last_response.status.should == 302
      last_response.location.should == 'https://example.org/AFNetworking/versions/1.2.0'
      Pod.first(:name => spec.name).versions.map(&:name).should == [spec.version.to_s]
    end

    it 'creates a commit once a push succeeds' do
      lambda do
        post '/', spec.to_json
      end.should.change { Commit.count }
      commit = Commit.first
      commit.committer.should == @owner
      commit.specification_data.should == JSON.pretty_generate(spec)
    end

    it 'does not create a commit if a push fails' do
      PushJob.any_instance.stubs(:push!).returns(response(500))
      lambda do
        post '/', spec.to_json
      end.should.not.change { Commit.count }
      last_response.status.should == 500
    end

    it 'still has the owner set if a push fails' do
      PushJob.any_instance.stubs(:push!).returns(response(500))
      post '/', spec.to_json
      Pod.find(:name => spec.name).owners.should == [@owner]
    end

    it 'informs the user if an exception occurs' do
      PushJob.any_instance.stubs(:push!).raises('Oh noes!')
      should.raise { post '/', spec.to_json } # This will return a 500 in dev/prod.
    end

    it 'informs the user if a timeout occurs' do
      response = response { raise Timeout::Error, 'execution expired' }
      PushJob.any_instance.stubs(:push!).returns(response)
      post '/', spec.to_json
      last_response.status.should == 504
    end
  end

  describe PodsController, 'when POSTing pod versions with an authenticated owner with validation' do
    extend SpecHelpers::PodsController

    before do
      response = response(201, { :commit => { :sha => '3ca23060197547eef92983f15590b5a87270615f' } }.to_json)
      PushJob.any_instance.stubs(:push!).returns(response)

      sign_in!
    end

    it 'does a HTTP check for http sources' do
      SpecificationWrapper.any_instance.stubs(:validate_http).returns(true)

      spec.source = { :http => 'https://hello.com' }
      lambda do
        post '/', spec.to_json
      end.should.change { Commit.count }
    end

    it 'does a git ls-remote check for git sources' do
      SpecificationWrapper.any_instance.stubs(:validate_git).returns(true)

      lambda do
        post '/', spec.to_json
      end.should.change { Commit.count }
    end

    it 'gives an error if http check fails' do
      SpecificationWrapper.any_instance.stubs(:validate_http).returns(false)

      spec.source = { :http => 'hello' }
      lambda do
        post '/', spec.to_json
      end.should.not.change { Commit.count }
      last_response.status.should == 403
      error_msg = 'Source code for your Pod was not accessible to CocoaPods Trunk. '\
        'Is it a private repo or behind a username/password on http?'
      json_response.should == { 'error' => error_msg }
    end

    it 'gives an error if git check fails' do
      SpecificationWrapper.any_instance.stubs(:validate_git).returns(false)
      lambda do
        post '/', spec.to_json
      end.should.not.change { Commit.count }
      last_response.status.should == 403
      error_msg = 'Source code for your Pod was not accessible to CocoaPods Trunk. '\
        'Is it a private repo or behind a username/password on http?'
      json_response.should == { 'error' => error_msg }
    end

    # pending "uses the CocoaPods HTTP validation api" do
    #   spec.source = { :http => "http://hello.com" }
    #   # Can't figure out how to do this
    #   HTTP.expects(:validate_url).with("http://hello.com").returns(true)
    #   post '/', spec.to_json
    # end

    it 'uses git ls for a GitHub git source' do
      SpecificationWrapper.any_instance.expects(:system).
        with('git', 'ls-remote', 'https://github.com/AFNetworking/AFNetworking.git', '1.2.0').
        returns(true)
      post '/', spec.to_json
    end

    it 'uses git ls for a BitBucket git source' do
      SpecificationWrapper.any_instance.expects(:system).
        with('git', 'ls-remote', 'https://bitbucket.org/technologyastronauts/oss_flounder.git', '1.2.0').
        returns(true)
      spec.source = { :git => 'https://bitbucket.org/technologyastronauts/oss_flounder.git', :tag => '1.2.0' }

      post '/', spec.to_json
    end

    it 'does not not run git ls for a non-GitHub git source' do
      SpecificationWrapper.any_instance.expects(:system).never

      spec.source = { :git => 'https://orta.io/thingy.git', :tag => '0.1.2' }
      post '/', spec.to_json
    end
  end

  describe PodsController, 'when PATCHing to deprecate a pod' do
    extend SpecHelpers::PodsController

    before do
      PushJob.any_instance.stubs(:push!).returns(*5.times.map do
        response(201, { :commit => { :sha => SecureRandom.hex(20) } }.to_json)
      end)

      @endpoint = '/AFNetworking/deprecated'
      @in_favor_of = { 'in_favor_of' => 'Alamofire' }.to_json
      @in_favor_of_nothing = { 'in_favor_of' => nil }.to_json
      sign_in!
    end

    it 'errors when deprecating a non-existent spec' do
      patch @endpoint, @in_favor_of
      last_response.status.should == 404
      json_response['error'].should == 'No pod found with the specified name.'
    end

    before do
      create_pod_version!
      @version.push!(@owner, spec.to_pretty_json, 'Add')
    end

    it 'errors when deprecating in favor of a non-existent pod' do
      lambda do
        patch @endpoint, @in_favor_of
      end.should.not.change { Commit.count }
      last_response.status.should == 422
      json_response['error'].should == 'You cannot deprecate a pod in favor of a pod that does not exist.'
    end

    it 'errors when there are no versions to deprecate' do
      DeprecateJob.any_instance.expects(:deprecate!).once.returns([])
      lambda do
        patch @endpoint, @in_favor_of_nothing
      end.should.not.change { Commit.count }
      last_response.status.should == 422
      json_response['error'].should == 'There were no published versions to deprecate.'
    end

    before do
      pod = Pod.create(:name => 'Alamofire')
      pod.add_owner(@owner) if @owner
      version = pod.add_version(:name => '1.0.0')
    end

    it 'deprecates the pod, then redirects' do
      lambda do
        patch @endpoint, @in_favor_of
      end.should.change { Commit.count }
      last_response.status.should == 302
      last_response.location.should == 'https://example.org/AFNetworking/versions/1.2.0'
      Pod.first(:name => spec.name).versions.map(&:name).should == [spec.version.to_s]
    end

    it 'creates a commit once a push succeeds' do
      lambda do
        patch @endpoint, @in_favor_of
      end.should.change { Commit.count }
      commit = Commit.last
      commit.committer.should == @owner
      commit.specification_data.should == JSON.pretty_generate(spec.dup.tap { |s| s.deprecated_in_favor_of = 'Alamofire' })
    end

    it 'creates a commit once a push succeeds' do
      lambda do
        patch @endpoint, @in_favor_of_nothing
      end.should.change { Commit.count }
      commit = Commit.last
      commit.committer.should == @owner
      commit.specification_data.should == JSON.pretty_generate(spec.dup.tap { |s| s.deprecated = true })
    end

    it 'does not create a commit if a push fails' do
      PushJob.any_instance.stubs(:push!).returns(response(500))
      lambda do
        patch @endpoint, @in_favor_of
      end.should.not.change { Commit.count }
      last_response.status.should == 500
    end

    it 'still has the owner set if a push fails' do
      PushJob.any_instance.stubs(:push!).returns(response(500))
      patch @endpoint, @in_favor_of
      Pod.find(:name => spec.name).owners.should == [@owner]
    end

    it 'informs the user if an exception occurs' do
      PushJob.any_instance.stubs(:push!).raises('Oh noes!')
      should.raise { patch @endpoint, @in_favor_of } # This will return a 500 in dev/prod.
    end

    it 'informs the user if a timeout occurs' do
      response = response { raise Timeout::Error, 'execution expired' }
      PushJob.any_instance.stubs(:push!).returns(response)
      patch @endpoint, @in_favor_of
      last_response.status.should == 504
    end
  end

  describe PodsController, 'when DELETEing to delete a pod version' do
    extend SpecHelpers::PodsController

    before do
      PushJob.any_instance.stubs(:push!).returns(*5.times.map do
        response(201, { :commit => { :sha => SecureRandom.hex(20) } }.to_json)
      end)

      @endpoint = '/AFNetworking/1.2.0'
      sign_in!
    end

    it 'errors when deleting a non-existent pod' do
      delete @endpoint
      last_response.status.should == 404
      json_response['error'].should == 'No pod found with the specified name.'
    end

    before do
      create_pod_version!
    end

    it 'errors when deleting a deleted version' do
      @version.update(:deleted => true)
      delete @endpoint
      last_response.status.should == 422
      json_response['error'].should == 'The version is already deleted.'
    end

    it 'errors when deleting a non-existent version' do
      delete @endpoint + '-pre'
      last_response.status.should == 404
      json_response['error'].should == 'No pod version found with the specified version.'
    end

    before do
      @version.push!(@owner, spec.to_pretty_json, 'Add')
    end

    it 'deletes the version, then responds' do
      lambda do
        delete @endpoint
      end.should.change { Commit.count }
      last_response.status.should == 302
      last_response.location.should == 'https://example.org/AFNetworking/versions/1.2.0'
      Pod.first(:name => spec.name).versions.map(&:deleted?).should == [true]
      Pod.first(:name => spec.name).versions.map { |v| v.last_published_by.specification_data }.should == ['{}']
    end

    it 'creates a commit once a push succeeds' do
      lambda do
        delete @endpoint
      end.should.change { Commit.count }
      commit = Commit.last
      commit.committer.should == @owner
      commit.specification_data.should == '{}'
    end

    it 'does not create a commit if a push fails' do
      PushJob.any_instance.stubs(:push!).returns(response(500))
      lambda do
        delete @endpoint
      end.should.not.change { Commit.count }
      last_response.status.should == 500
    end

    it 'still has the owner set if a push fails' do
      PushJob.any_instance.stubs(:push!).returns(response(500))
      delete @endpoint
      Pod.find(:name => spec.name).owners.should == [@owner]
    end

    it 'informs the user if an exception occurs' do
      PushJob.any_instance.stubs(:push!).raises('Oh noes!')
      should.raise { delete @endpoint } # This will return a 500 in dev/prod.
    end

    it 'informs the user if a timeout occurs' do
      response = response { raise Timeout::Error, 'execution expired' }
      PushJob.any_instance.stubs(:push!).returns(response)
      delete @endpoint
      last_response.status.should == 504
    end
  end

  describe PodsController, 'with an unauthenticated consumer' do
    extend SpecHelpers::PodsController

    should_require_login.post('/') { spec.to_json }

    before do
      create_pod_version!
    end

    should_require_login.patch('/AFNetworking/owners') do
      { 'email' => 'other@example.com' }.to_json
    end

    should_require_login.delete('/AFNetworking/owners/other@example.com') { '' }

    it "returns a 404 when a pod or version can't be found" do
      get '/FANetworking/versions/1.2.0'
      last_response.status.should == 404
      get '/AFNetworking/versions/0.2.1'
      last_response.status.should == 404
    end

    it 'considers a pod nonexistent if no version is published yet' do
      get '/AFNetworking'
      last_response.status.should == 404
      last_response.body.should == { 'error' => 'No pod found with the specified name.' }.to_json
    end

    it 'returns an overview of a pod including only the published versions' do
      create_session_with_owner
      @pod.add_owner(@owner)
      @pod.add_version(:name => '0.2.1')
      @version.add_commit(valid_commit_attrs)
      get '/AFNetworking'
      last_response.body.should == {
        'versions' => [@version.public_attributes],
        'owners' => [@owner.public_attributes],
      }.to_json
    end

    it "considers a pod version nonexistent if it's not yet published" do
      get '/AFNetworking/versions/1.2.0'
      last_response.status.should == 404
      last_response.body.should == { 'error' => 'No pod found with the specified version.' }.to_json
    end

    before do
      @owner = Owner.create(:email => 'appie@example.com', :name => 'Appie')
      @version.add_commit(valid_commit_attrs)
    end

    it 'returns an overview of a published pod version' do
      get '/AFNetworking/versions/1.2.0'
      last_response.status.should == 200
      last_response.body.should == {
        'messages' => @version.log_messages.map(&:public_attributes),
        'data_url' => @version.data_url,
      }.to_json
    end

    it "considers a pod version nonexistent if it's marked as being deleted" do
      @pod.update(:deleted => true)
      get '/AFNetworking'
      last_response.status.should == 404
      last_response.body.should == { 'error' => 'No pod found with the specified name.' }.to_json
      get '/AFNetworking/versions/1.2.0'
      last_response.status.should == 404
      last_response.body.should == { 'error' => 'No pod found with the specified version.' }.to_json
    end
  end

  describe PodsController, 'concerning authorization' do
    extend SpecHelpers::PodsController

    before do
      response = response(201, { :commit => { :sha => '3ca23060197547eef92983f15590b5a87270615f' } }.to_json)
      PushJob.any_instance.stubs(:push!).returns(response)
      SpecificationWrapper.any_instance.stubs(:publicly_accessible?).returns(true)

      sign_in!
    end

    it 'allows a push for an existing pod owned by the authenticated owner' do
      @owner.add_pod(:name => spec.name)
      lambda do
        lambda do
          post '/', spec.to_json
        end.should.not.change { Pod.count }
      end.should.change { PodVersion.count }
    end

    before do
      @other_owner = Owner.create(:email => 'jenny@example.com', :name => 'Jenny')
    end

    seed_unclaimed

    it "adds an owner to the pod's owners" do
      pod = @owner.add_pod(:name => spec.name)
      patch '/AFNetworking/owners', { 'email' => @other_owner.email }.to_json
      last_response.status.should == 200
      pod.owners.sort_by(&:name).should == [@owner, @other_owner].sort_by(&:name)
    end

    it 'does nothing when the owner is already an owner' do
      pod = @owner.add_pod(:name => spec.name)
      @other_owner.add_pod(pod)
      patch '/AFNetworking/owners', { 'email' => @other_owner.email }.to_json
      last_response.status.should == 200
      pod.owners.sort_by(&:name).should == [@owner, @other_owner].sort_by(&:name)
    end

    it 'removes an owner from a pod' do
      pod = @owner.add_pod(:name => spec.name)
      @other_owner.add_pod(pod)
      delete "/AFNetworking/owners/#{@other_owner.email}"
      last_response.status.should == 200
      pod.owners.sort_by(&:name).should == [@owner].sort_by(&:name)
    end

    it 'errors when attempting to remove an owner who does not own the pod' do
      pod = @owner.add_pod(:name => spec.name)
      delete "/AFNetworking/owners/#{@other_owner.email}"
      last_response.status.should == 404
      last_response.body.should.match /does not own this pod/
    end

    it 'marks the pod as unclaimed when the last owner removes themself' do
      pod = @owner.add_pod(:name => spec.name)
      delete "/AFNetworking/owners/#{@owner.email}"
      pod.owners.should == [Owner.unclaimed]
    end

    before do
      @other_pod = @other_owner.add_pod(:name => spec.name)
    end

    # TODO: see if changes (or the lack of) can be detected from the macro, besides just count.
    it "does not allow to remove an owner from a pod that's not owned by the authenticated owner" do
      delete "/AFNetworking/owners/#{@other_owner.email}"
      last_response.status.should == 403
      @other_pod.owners.should == [@other_owner]
    end

    # TODO: see if changes (or the lack of) can be detected from the macro, besides just count.
    it "does not allow to add an owner to a pod that's not owned by the authenticated owner" do
      patch '/AFNetworking/owners', { 'email' => @owner.email }.to_json
      @other_pod.owners.should == [@other_owner]
    end

    should_disallow.post('/') { spec.to_json }
    should_disallow.patch('/AFNetworking/owners') do
      { 'email' => @owner.email }.to_json
    end
  end

  describe PodsController, 'concerning specs' do
    extend SpecHelpers::PodsController

    before do
      create_pod_version!
      create_session_with_owner
      @pod.add_owner(@owner)
      @pod.add_version(:name => '0.2.1').add_commit(valid_commit_attrs)
      @pod.add_version(:name => '1.2.0-beta1').add_commit(valid_commit_attrs)
      @pod.add_version(:name => '6.2.1')
      @version.add_commit(valid_commit_attrs)
    end

    it "returns a 404 when a pod or version can't be found" do
      get '/FANetworking/specs/1.2.0'
      last_response.status.should == 404
      get '/FANetworking/specs/latest'
      last_response.status.should == 404
      get '/AFNetworking/specs/6.2.1'
      last_response.status.should == 404
    end

    it 'redirects to GitHub when a version is found' do
      get '/AFNetworking/specs/latest'
      last_response.should.be.redirect?
      last_response.headers['Location'].should == 'https://raw.githubusercontent.com/' \
        'CocoaPods/Specs/3ca23060197547eef92983f15590b5a87270615f/Specs/AFNetworking/1.2.0/AFNetworking.podspec.json'

      get '/AFNetworking/specs/1.2.0'
      last_response.should.be.redirect?
      last_response.headers['Location'].should == 'https://raw.githubusercontent.com/' \
        'CocoaPods/Specs/3ca23060197547eef92983f15590b5a87270615f/Specs/AFNetworking/1.2.0/AFNetworking.podspec.json'
    end

    it 'redirects to GitHub when a post-shard version is found' do
      PodVersion::SOURCE_METADATA.stubs(:prefix_lengths).returns([1, 1, 1])
      Commit.dataset.update(:created_at => DateTime.now)
      get '/AFNetworking/specs/latest'
      last_response.should.be.redirect?
      last_response.headers['Location'].should == 'https://raw.githubusercontent.com/' \
        'CocoaPods/Specs/3ca23060197547eef92983f15590b5a87270615f/Specs/a/7/5/AFNetworking/1.2.0/AFNetworking.podspec.json'

      get '/AFNetworking/specs/1.2.0'
      last_response.should.be.redirect?
      last_response.headers['Location'].should == 'https://raw.githubusercontent.com/' \
        'CocoaPods/Specs/3ca23060197547eef92983f15590b5a87270615f/Specs/a/7/5/AFNetworking/1.2.0/AFNetworking.podspec.json'
    end

    it 'redirects to GitHub when a pre-shard version is found' do
      PodVersion::SOURCE_METADATA.stubs(:prefix_lengths).returns([1, 1, 1])
      Commit.dataset.update(:created_at => DateTime.new(1900))
      get '/AFNetworking/specs/latest'
      last_response.should.be.redirect?
      last_response.headers['Location'].should == 'https://raw.githubusercontent.com/' \
        'CocoaPods/Specs/3ca23060197547eef92983f15590b5a87270615f/Specs/AFNetworking/1.2.0/AFNetworking.podspec.json'

      get '/AFNetworking/specs/1.2.0'
      last_response.should.be.redirect?
      last_response.headers['Location'].should == 'https://raw.githubusercontent.com/' \
        'CocoaPods/Specs/3ca23060197547eef92983f15590b5a87270615f/Specs/AFNetworking/1.2.0/AFNetworking.podspec.json'
    end
  end
end
