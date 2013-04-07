require File.expand_path('../../spec_helper', __FILE__)

module Pod::PushApp
  describe "PodVersion" do
    describe "concerning finding/creating a pod and version" do
      it "creates and returns a new record when there is no existing match for the library's name and version" do
        lambda do
          lambda do
            version = PodVersion.by_name_and_version('AFNetworking', '1.2.0')
            version.name.should == '1.2.0'
            version.pod.name.should == 'AFNetworking'
          end.should.change? { Pod.count }
        end.should.change? { PodVersion.count }
      end

      before do
        @pod = Pod.create(:name => 'AFNetworking')
        @version = PodVersion.create(:pod => @pod, :name => '1.2.0')
      end

      it "returns an existing library record matching the specified name and version" do
        lambda do
          version = PodVersion.by_name_and_version('AFNetworking', '1.2.0')
          version.should == @version
          version.pod.should == @pod
        end.should.not.change? { Pod.count + PodVersion.count }
      end

      it "creates a new associated version for an existing library record" do
        lambda do
          lambda do
            version = PodVersion.by_name_and_version('AFNetworking', '1.2.1')
            version.name.should == '1.2.1'
            version.pod.name.should == 'AFNetworking'
          end.should.not.change? { Pod.count }
        end.should.change? { PodVersion.count }
      end
    end

    #describe "concerning submission progress state" do
      #before do
        #@pod = Pod.create(:name => 'AFNetworking')
        #@version = PodVersion.create(:pod => @pod, :name => '1.2.0')
      #end

      #it "initializes with a `new` state" do
        #@version.state.should == nil
        #@version.should.be.new
      #end

      #it "changes state to `pull-request`" do
      #end
    #end
  end
end
