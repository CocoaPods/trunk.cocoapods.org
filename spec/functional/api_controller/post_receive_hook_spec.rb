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
      payload = {
        :payload => {
          :before     => 'before',
          :after      => 'after',
          :ref        => 'ref',
          :commits    => [{
            :id        => 'fc2d273fca03aceaf7f0d3843c06165a106dcd13',
            :message   => '[Add] BendingSpoons-iOSKit 0.0.94',
            :timestamp => '',
            :url       => '',
            :added     => [],
            :removed   => [],
            :modified  => ['Specs/BendingSpoons-iOSKit/0.0.94/BendingSpoons-iOSKit.podspec.json'],
            :author    => {
              :name  => 'Eloy Durán',
              :email => 'alloy@cocoapods.org'
            },
            :committer => {
              :name => 'CocoaPods Bot',
              :email => 'bot@cocoapods.org'
            }
          },{
            :id        => '24a5a403e1f1fadd17ebe8e43d0c6dc6e66c81ba',
            :message   => 'Update Analytics 0.9.5',
            :timestamp => 'commit.committed_date.xmlschema',
            :url       => 'commit_url',
            :added     => [],
            :removed   => [],
            :modified  => ['Specs/Analytics/0.9.5/Analytics.podspec.json'],
            :author    => {
              :name  => 'Eloy Durán',
              :email => 'alloy@cocoapods.org'
            },
            :committer => {
              :name => 'Keith Smiley',
              :email => 'smiles@cocoapods.org'
            }
          }],
          :repository => {
            :name        => 'Specs',
            :url         => 'https://github.com/CocoaPods/Specs',
            :pledgie     => '',
            :description => 'A repository of CocoaPods (cocoapods.org) specifications.',
            :homepage    => 'http://docs.cocoapods.org/guides/contributing_to_the_master_repo.html',
            :watchers    => 170,
            :forks       => 2787,
            :private     => false,
            :owner => {
              :name  => 'CocoaPods',
              :email => 'owner@cocoapods.org'
            }
          }
        }
      }.to_json
      post '/post-receive-hook/', payload
      last_response.status.should == 200
    end
    
  end
  
end