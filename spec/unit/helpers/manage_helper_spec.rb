require File.expand_path('../../../spec_helper', __FILE__)

module Pod::TrunkApp
  describe ManageHelper do
    extend ManageHelper

    it 'formats a duration which includes seconds' do
      formatted_duration(1).should == '1 second'
      formatted_duration(59).should == '59 seconds'
    end

    it 'formats a duration which includes minutes' do
      formatted_duration(61).should == '1 minute and 1 second'
      formatted_duration(3599).should == '59 minutes and 59 seconds'
    end

    it 'formats a duration which includes hours' do
      formatted_duration(3601).should == '1 hour'
      formatted_duration(3660).should == '1 hour and 1 minute'
    end

    it 'formats a duration which includes days' do
      formatted_duration(3600 * 24).should == '1 day'
      formatted_duration(3600 * 25).should == '1 day and 1 hour'
    end
  end
end
