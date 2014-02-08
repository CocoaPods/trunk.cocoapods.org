require File.expand_path('../../../spec_helper', __FILE__)

module Pod::TrunkApp
  class APIController
    def raise_test_error
    end

    get '/raise_test_error' do
      raise_test_error
    end
  end

  describe APIController, "concerning error handling" do
    extend SpecHelpers::Response

    before do
      header 'Content-Type', 'application/json; charset=utf-8'
    end

    it "catches JSON parse errors" do
      error = JSON::ParserError.new('invalid')
      APIController.any_instance.stubs(:raise_test_error).raises(error)

      get '/raise_test_error'
      last_response.status.should == 400
      json_response['error'].should == 'Invalid JSON data provided.'
    end

    it "catches model validation errors" do
      errors = Sequel::Model::Errors.new
      errors.add(:name, 'invalid')
      error = Sequel::ValidationFailed.new(errors)
      APIController.any_instance.stubs(:raise_test_error).raises(error)

      get '/raise_test_error'
      last_response.status.should == 422
      json_response['error'].should == { 'name' => ['invalid'] }
    end

    #it "catches constraint errors" do
    #end

    it "catches all other unexpected errors" do
      APIController.any_instance.stubs(:raise_test_error).raises
      get '/raise_test_error'
      last_response.status.should == 500
      json_response['error'].should == 'An internal server error occurred. Please try again later.'
    end

    it "reports all unexpected errors" do
      error = StandardError.new('oops')
      APIController.any_instance.stubs(:raise_test_error).raises(error)
      NewRelic::Agent.expects(:notice_error).with(error, :uri => '/raise_test_error',
                                                         :referer => 'http://example.com',
                                                         :request_params => { 'key' => 'value' })
      get '/raise_test_error', { 'key' => 'value' }, { 'HTTP_REFERER' => 'http://example.com' }
    end
  end
end
