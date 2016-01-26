require File.expand_path('../../spec_helper', __FILE__)
require 'app/controllers/api_controller'

module Pod::TrunkApp
  class APIController
    def raise_test_error
    end

    get '/raise_test_error', :requires_owner => false do
      raise_test_error
    end
  end

  describe APIController, 'concerning error handling' do
    extend SpecHelpers::Response

    before do
      header 'Content-Type', 'application/json; charset=utf-8'
    end

    it 'catches JSON parse errors' do
      error = JSON::ParserError.new('invalid')
      APIController.any_instance.stubs(:raise_test_error).raises(error)

      get '/raise_test_error'
      last_response.status.should == 400
      json_response['error'].should == 'Invalid JSON data provided.'
    end

    it 'catches model validation errors' do
      errors = Sequel::Model::Errors.new
      errors.add(:name, 'invalid')
      error = Sequel::ValidationFailed.new(errors)
      APIController.any_instance.stubs(:raise_test_error).raises(error)

      get '/raise_test_error'
      last_response.status.should == 422
      json_response['error'].should == { 'name' => ['invalid'] }
    end

    before do
      APIController.any_instance.stubs(:catch_unexpected_errors?).returns(true)
    end

    it 'catches all other unexpected errors' do
      APIController.any_instance.stubs(:raise_test_error).raises
      get '/raise_test_error'
      last_response.status.should == 500
      json_response['error'].should.match /An internal server error occurred/
    end

    it 'reports all unexpected errors' do
      error = StandardError.new('oops')
      APIController.any_instance.stubs(:raise_test_error).raises(error)
      # TODO: Twice? Yeah sure, I have no clue. The earlier one appears to be
      # raised from inside Sequel (by NewRelic's plugin). Let's see what
      # happens in production.
      NewRelic::Agent.expects(:notice_error).with(error)
      NewRelic::Agent.expects(:notice_error).with(error, :uri => '/raise_test_error',
                                                         :referer => 'http://example.com',
                                                         :request_params => { 'key' => 'value' })
      get '/raise_test_error', { 'key' => 'value' }, 'HTTP_REFERER' => 'http://example.com'
    end
  end

  class APIController
    get '/owner_required', :requires_owner => true do
    end
  end

  describe APIController, 'concerning authentication' do
    extend SpecHelpers::Response
    extend SpecHelpers::Authentication

    before do
      header 'Content-Type', 'application/json; charset=utf-8'
    end

    it 'allows access with a valid verified session belonging to an owner' do
      session = create_session_with_owner
      get '/owner_required', nil, 'HTTP_AUTHORIZATION' => "Token #{session.token}"
      last_response.status.should == 200
    end

    it 'does not allow access when no authentication token is supplied' do
      get '/owner_required'
      last_response.status.should == 401
      json_response['error'].should == 'Please supply an authentication token.'
    end

    it 'does not allow access when an invalid authentication token is supplied' do
      get '/owner_required', nil,  'HTTP_AUTHORIZATION' => 'Token invalid'
      last_response.status.should == 401
      json_response['error'].should.match /Authentication token is invalid or unverified/
    end

    it 'does not allow access when an unverified authentication token is supplied' do
      session = create_session_with_owner
      session.update(:verified => false)
      get '/owner_required', nil, 'HTTP_AUTHORIZATION' => "Token #{session.token}"
      last_response.status.should == 401
      json_response['error'].should.match /Authentication token is invalid or unverified/
    end
  end
end
