require File.expand_path('../../spec_helper', __FILE__)
require 'app/models/session'

module Pod::TrunkApp
  describe Session do
    before do
      @owner = Owner.create(:email => 'appie@example.com', :name => 'Appie Duran')
    end

    describe 'when initializing' do
      it 'is not verified yet' do
        Session.new.verified.should == false
      end

      it 'automatically creates a token and a verification token for itself' do
        session = Session.new
        session.token.length.should == 32
        session.verification_token.length.should == 8
      end

      it 'sets a default expiration date' do
        expected = Time.current + 128.days
        Session.new.valid_until.to_s.should == expected.to_s
      end
    end

    describe 'concerning validations' do
      before do
        @session = Session.new(:owner => @owner, :created_from_ip => '1.2.3.4')
      end

      it 'needs a owner' do
        @session.should.not.validate_with(:owner_id, nil)
        @session.should.validate_with(:owner_id, 42)
      end

      it 'needs an IP address' do
        @session.should.not.validate_with(:created_from_ip, nil)
        @session.should.validate_with(:created_from_ip, '1.2.3.4')
      end

      describe 'at the DB level' do
        it 'raises if an empty token gets inserted' do
          should.raise Sequel::NotNullConstraintViolation do
            @session.token = nil
            @session.save(:validate => false)
          end
        end

        it 'raises if an empty owner_id gets inserted' do
          should.raise Sequel::NotNullConstraintViolation do
            @session.owner_id = nil
            @session.save(:validate => false)
          end
        end

        it 'raises if an empty verified gets inserted' do
          should.raise Sequel::NotNullConstraintViolation do
            @session.verified = nil
            @session.save(:validate => false)
          end
        end

        it 'raises if an empty valid_until gets inserted' do
          should.raise Sequel::NotNullConstraintViolation do
            @session.valid_until = nil
            @session.save(:validate => false)
          end
        end

        it 'raises if an empty created_from_ip address gets inserted' do
          should.raise Sequel::NotNullConstraintViolation do
            @session.created_from_ip = nil
            @session.save(:validate => false)
          end
        end

        %w(token verification_token).each do |attr|
          it "raises if a duplicate #{attr} gets inserted" do
            Session.create(attr => 'secret', :owner => @owner, :created_from_ip => '1.2.3.4')
            should.raise Sequel::UniqueConstraintViolation do
              Session.create(attr => 'secret', :owner => @owner, :created_from_ip => '1.2.3.4')
            end
          end
        end
      end
    end

    describe 'finders' do
      before do
        @session = Session.new(:owner => @owner, :created_from_ip => '1.2.3.4')
        @session.verified = true
        @session.save
      end

      it 'finds nothing for a blank token' do
        Session.with_token(nil).should.be.nil
        Session.with_verification_token(nil).should.be.nil
      end

      it 'finds a valid session based on a token' do
        Session.with_token(@session.token).should == @session
        Session.with_verification_token(@session.verification_token).should == @session
      end

      it 'does not find an invalid session based on a token' do
        @session.update(:valid_until => 1.second.ago)
        Session.with_token(@session.token).should.be.nil
        Session.with_verification_token(@session.verification_token).should.be.nil
      end

      it 'does not find a session with a wrong token' do
        Session.with_token('wrong').should.be.nil
        Session.with_verification_token('wrong').should.be.nil
      end

      it 'does not find an unverified session' do
        @session.update(:verified => false)
        Session.with_token(@session.token).should.be.nil
      end

      it 'finds an unverified session by verification token' do
        @session.update(:verified => false)
        Session.with_verification_token(@session.verification_token).should == @session.reload
      end
    end

    it 'coerces to JSON' do
      json = JSON.parse(Session.new.to_json)
      json.keys.sort.should == %w(created_at created_from_ip description valid_until verified)
    end

    it 'verifies a session' do
      session = Session.create(:owner => @owner, :created_from_ip => '1.2.3.4')
      session.verify!
      session.reload.verified.should == true
      session.verification_token.should.be.nil
    end

    it 'extends the validity' do
      session = Session.create(:owner => @owner, :created_from_ip => '1.2.3.4')
      session.update(:valid_until => 10.seconds.from_now, :verified => true)
      session.prolong!
      session.reload.valid_until.should > 10.seconds.from_now
    end

    it 'does not extend the validity of an invalid session' do
      session = Session.create(:owner => @owner, :created_from_ip => '1.2.3.4')
      session.update(:valid_until => 10.seconds.ago, :verified => true)
      lambda { session.prolong! }.should.raise
      session = Session.create(:owner => @owner, :created_from_ip => '1.2.3.4')
      session.update(:valid_until => 10.seconds.from_now, :verified => false)
      lambda { session.prolong! }.should.raise
    end
  end
end
