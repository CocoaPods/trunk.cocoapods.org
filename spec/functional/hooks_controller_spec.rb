require File.expand_path('../../spec_helper', __FILE__)

module Pod::TrunkApp
  
  describe HooksController, "when receiving push updates from the repository" do
    
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
    
    it "fails with media type other than JSON data" do
      header 'Content-Type', 'text/yaml'
      post '/github-post-receive/', ''
      last_response.status.should == 415
    end
    
    it "fails with data other than a push payload" do
      header 'Content-Type', 'application/x-www-form-urlencoded'
      post '/github-post-receive/', something: 'else'
      last_response.status.should == 422
    end
    
    it "fails with a payload other than serialized push data" do
      header 'Content-Type', 'application/x-www-form-urlencoded'
      post '/github-post-receive/', payload: 'not-push-data'
      last_response.status.should == 415
    end
    
    it "processes payload data but does not create a new pod (if one does not exist)" do
      # TODO Replace the old-school podspec with a JSON style one.
      #
      REST.stubs(:get).returns(fixture_specification('GitHub/MobileAppTracker.podspec'))
    
      header 'Content-Type', 'application/x-www-form-urlencoded'
      payload = fixture_read('GitHub/post_receive_hook_data.raw')
      post '/github-post-receive/', payload
    
      last_response.status.should == 200
    
      Pod.find(name: 'MobileAppTracker').should == nil
    end
    
    it "processes payload data and does create a new pod version (if it does not exist)" do
      # Create existing pod.
      #
      existing_spec = fixture_specification('AFNetworking.podspec')
      existing_pod = Pod.create(:name => existing_spec.name)
      PodVersion.create(:pod => existing_pod, :name => existing_spec.version.version)
      
      # TODO Replace the old-school podspec with a JSON style one.
      #
      REST.stubs(:get).returns(fixture_specification('GitHub/AFNetworking.podspec'))
    
      header 'Content-Type', 'application/x-www-form-urlencoded'
      payload = fixture_read('GitHub/post_receive_hook_data.raw')
      post '/github-post-receive/', payload
    
      last_response.status.should == 200
    
      Pod.find(name: 'AFNetworking').versions.map(&:name).should == ['1.2.0', '1.2.1']
    end
    
    it "processes payload data and does not create a new pod version (because it exists)" do
      # Create existing pod.
      #
      existing_spec = fixture_specification('AFNetworking.podspec')
      existing_pod = Pod.create(:name => existing_spec.name)
      PodVersion.create(:pod => existing_pod, :name => existing_spec.version.version)
      
      # TODO Replace the old-school podspec with a JSON style one.
      #
      REST.stubs(:get).returns(existing_spec)
    
      header 'Content-Type', 'application/x-www-form-urlencoded'
      payload = fixture_read('GitHub/post_receive_hook_data.raw')
      post '/github-post-receive/', payload
    
      last_response.status.should == 200
    
      Pod.find(name: 'AFNetworking').versions.map(&:name).should == ['1.2.0']
    end
    
  end
  
end
