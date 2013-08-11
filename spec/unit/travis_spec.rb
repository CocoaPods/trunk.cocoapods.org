require File.expand_path('../../spec_helper', __FILE__)
require 'app/models/travis'

module Pod::TrunkApp
  describe Travis do
    it "returns that a build is not finished yet" do
      travis = Travis.new(fixture_json('TravisCI/pull-request_start_payload.json'))
      travis.should.not.be.finished
    end

    it "returns that a build is finished and that it was a success" do
      travis = Travis.new(fixture_json('TravisCI/pull-request_success_payload.json'))
      travis.should.be.finished
      travis.should.be.build_success
    end

    it "returns that a build is finished and that it was not a success" do
      travis = Travis.new(fixture_json('TravisCI/pull-request_failure_payload.json'))
      travis.should.be.finished
      travis.should.not.be.build_success
    end

    it "returns the pull-request number and build URL" do
      [
        'TravisCI/pull-request_start_payload.json',
        'TravisCI/pull-request_success_payload.json',
        'TravisCI/pull-request_failure_payload.json',
        'TravisCI/api_pull-request_payload.json'
      ].each do |fixture_name|
        travis = Travis.new(fixture_json(fixture_name))
        travis.pull_request_number.should == NEW_PR_NUMBER
        travis.build_url.should == 'https://travis-ci.org/CocoaPods/Specs/builds/7540815'
      end
    end
  end
end
