require File.expand_path('../../../spec_helper', __FILE__)

module Pod::TrunkApp
  
  describe APIController, "when receiving push updates from the repository" do

    it "fails with media type other than JSON data" do
      header 'Content-Type', 'text/yaml'
      post '/post-receive-hook/', ''
      last_response.status.should == 415
    end

    it "silently fails with data other than a push payload" do
      header 'Content-Type', 'application/json'
      post '/post-receive-hook/', something: 'else'
      last_response.status.should == 200
    end
    
    it "silently fails with a payload other than serialized push data" do
      header 'Content-Type', 'application/json'
      post '/post-receive-hook/', payload: 'not-push-data'
      last_response.status.should == 200
    end
    
    it "processes a payload of serialized push data" do
      header 'Content-Type', 'application/json'
      payload = fixture_read('GitHub/post_receive_hook_data.raw')
      post '/post-receive-hook/', payload
      last_response.status.should == 200
    end
    
  end
  
end