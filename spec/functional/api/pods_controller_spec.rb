require File.expand_path('../../../spec_helper', __FILE__)
require 'app/controllers/api/pods_controller'

module SpecHelpers::PodsController
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
    { :committer => @owner, :specification_data => 'DATA' }
  end

  def create_pod_version!
    @pod = Pod::TrunkApp::Pod.create(:name => spec.name)
    @pod.add_owner(@owner) if @owner
    @version = @pod.add_version(:name => spec.version.to_s)
  end
end

module Pod::TrunkApp
  describe PodsController, "when POSTing pod versions with an authenticated owner" do
    extend SpecHelpers::PodsController

    before do
      PushJob.any_instance.stubs(:push!).returns('3ca23060197547eef92983f15590b5a87270615f')
      sign_in!
    end

    it "only accepts JSON" do
      header 'Content-Type', 'text/yaml'
      post '/', {}, { 'HTTPS' => 'on' }
      last_response.status.should == 415
    end

    it "does not accept a push unless explicitely enabled" do
      begin
        [nil, '', 'false'].each do |value|
          ENV['TRUNK_APP_PUSH_ALLOWED'] = value
          lambda {
            post '/', spec.to_json
          }.should.not.change { Pod.count + PodVersion.count }
          last_response.status.should == 503
          json_response['error'].should == 'Push access is currently disabled.'
        end
      ensure
        ENV['TRUNK_APP_PUSH_ALLOWED'] = 'true'
      end
    end

    it "fails with data other than serialized spec data" do
      lambda {
        post '/', ''
      }.should.not.change { Pod.count + PodVersion.count }
      last_response.status.should == 400

      lambda {
        post '/', '{"something":"else"}'
      }.should.not.change { Pod.count + PodVersion.count }
      last_response.status.should == 422
    end

    it "fails with a spec that does not pass a quick lint" do
      spec.name = nil
      spec.version = nil
      spec.license = nil

      lambda {
        post '/', spec.to_json
      }.should.not.change { Pod.count + PodVersion.count }

      last_response.status.should == 422
      json_response.should == {
        'error' => {
          'errors'   => ['Missing required attribute `name`.', 'A version is required.'],
          'warnings' => ['Missing required attribute `license`.', 'Missing license type.']
        }
      }
    end

    it "does not allow a push for an existing pod version if it's published" do
      @owner.add_pod(:name => spec.name)
            .add_version(:name => spec.version.to_s)
            .add_commit(valid_commit_attrs)
      lambda {
        post '/', spec.to_json
      }.should.not.change { Pod.count + PodVersion.count }
      last_response.status.should == 409
      last_response.location.should == 'https://example.org/pods/AFNetworking/versions/1.2.0'
    end

    it "creates new pod and version records" do
      lambda {
        lambda {
          post '/', spec.to_json
        }.should.change { Pod.count }
      }.should.change { PodVersion.count }
      last_response.status.should == 302
      last_response.location.should == 'https://example.org/pods/AFNetworking/versions/1.2.0'
      Pod.first(:name => spec.name).versions.map(&:name).should == [spec.version.to_s]
    end

    it "creates a commit once a push succeeds" do
      PushJob.any_instance.expects(:push!).returns('3ca23060197547eef92983f15590b5a87270615f')
      lambda {
        post '/', spec.to_json
      }.should.change { Commit.count }
      commit = Commit.first
      commit.committer.should == @owner
      commit.specification_data.should == JSON.pretty_generate(spec)
    end
    
    it "does not create commit if a push fails" do
      PushJob.any_instance.expects(:push!).returns(nil)
      lambda {
        post '/', spec.to_json
      }.should.not.change { Commit.count }
    end
  end

  describe PodsController, "with an unauthenticated consumer" do
    extend SpecHelpers::PodsController

    should_require_login.post('/') { spec.to_json }

    before do
      create_pod_version!
    end

    should_require_login.patch('/AFNetworking/owners') do
      { 'email' => 'other@example.com' }.to_json
    end

    it "returns a 404 when a pod or version can't be found" do
      get '/FANetworking/versions/1.2.0'
      last_response.status.should == 404
      get '/AFNetworking/versions/0.2.1'
      last_response.status.should == 404
    end

    it "considers a pod non-existant if no version is published yet" do
      get '/AFNetworking'
      last_response.status.should == 404
      last_response.body.should == { 'error' => 'No pod found with the specified name.' }.to_json
    end

    it "returns an overview of a pod including only the published versions" do
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

    it "considers a pod version non-existant if it's not yet published" do
      get '/AFNetworking/versions/1.2.0'
      last_response.status.should == 404
      last_response.body.should == { 'error' => 'No pod found with the specified version.' }.to_json
    end

    it "returns an overview of a published pod version" do
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

  describe PodsController, "concerning authorization" do
    extend SpecHelpers::PodsController

    before do
      PushJob.any_instance.stubs(:push!).returns(true)
      sign_in!
    end

    it "allows a push for an existing pod owned by the authenticated owner" do
      @owner.add_pod(:name => spec.name)
      lambda {
        lambda {
          post '/', spec.to_json
        }.should.not.change { Pod.count }
      }.should.change { PodVersion.count }
    end

    before do
      @other_owner = Owner.create(:email => 'jenny@example.com', :name => 'Jenny')
    end

    it "adds an owner to the pod's owners" do
      pod = @owner.add_pod(:name => spec.name)
      patch '/AFNetworking/owners', { 'email' => @other_owner.email }.to_json
      last_response.status.should == 200
      pod.owners.should == [@owner, @other_owner]
    end

    before do
      @other_pod = @other_owner.add_pod(:name => spec.name)
    end

    # TODO see if changes (or the lack of) can be detected from the macro, besides just count.
    it "does not allow to add an owner to a pod that's not owned by the authenticated owner" do
      patch '/AFNetworking/owners', { 'email' => @owner.email }.to_json
      @other_pod.owners.should == [@other_owner]
    end

    should_disallow.post('/') { spec.to_json }
    should_disallow.patch('/AFNetworking/owners') do
      { 'email' => @owner.email }.to_json
    end
  end
end
