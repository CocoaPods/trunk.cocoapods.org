require File.expand_path('../../../spec_helper', __FILE__)
require 'app/controllers/api/pods_controller'

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
      :specification_data => 'DATA'
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

      sign_in!
    end

    it 'only accepts JSON' do
      header 'Content-Type', 'text/yaml'
      post '/', {},  'HTTPS' => 'on'
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
          json_response['error'].should.match /Push access is currently disabled/
        end
      ensure
        ENV['TRUNK_APP_PUSH_ALLOWED'] = 'true'
      end
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
          'warnings' => ['Missing required attribute `license`.', 'Missing license type.']
        }
      }
    end

    it 'does not allow a push for an existing pod with different case' do
      @owner.add_pod(:name => spec.name.upcase)
      lambda do
        post '/', spec.to_json
      end.should.not.change { Pod.count }
      last_response.status.should == 422
      json_response.should == { 'error' => { 'name' => ['is already taken'] } }
    end

    it "does not allow a push for an existing pod version if it's published" do
      @owner.add_pod(:name => spec.name)
            .add_version(:name => spec.version.to_s)
            .add_commit(valid_commit_attrs)
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

    it 'considers a pod non-existant if no version is published yet' do
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
        'owners' => [@owner.public_attributes]
      }.to_json
    end

    it "considers a pod version non-existant if it's not yet published" do
      get '/AFNetworking/versions/1.2.0'
      last_response.status.should == 404
      last_response.body.should == { 'error' => 'No pod found with the specified version.' }.to_json
    end

    it 'returns an overview of a published pod version' do
      @owner = Owner.create(:email => 'appie@example.com', :name => 'Appie')
      @version.add_commit(valid_commit_attrs)
      get '/AFNetworking/versions/1.2.0'
      last_response.status.should == 200
      last_response.body.should == {
        'messages' => @version.log_messages.map(&:public_attributes),
        'data_url' => @version.data_url
      }.to_json
    end
  end

  describe PodsController, 'concerning authorization' do
    extend SpecHelpers::PodsController

    before do
      response = response(201, { :commit => { :sha => '3ca23060197547eef92983f15590b5a87270615f' } }.to_json)
      PushJob.any_instance.stubs(:push!).returns(response)

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
      @pod.add_version(:name => '0.2.1')
      @version.add_commit(valid_commit_attrs)
    end

    it "returns a 404 when a pod or version can't be found" do
      get '/FANetworking/specs/1.2.0'
      last_response.status.should == 404
      get '/FANetworking/specs/latest'
      last_response.status.should == 404
      get '/AFNetworking/specs/0.2.1'
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
  end
end
