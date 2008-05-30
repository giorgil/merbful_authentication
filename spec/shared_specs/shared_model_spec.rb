describe "A MerbfulAuthentication User Model", :shared => true do
  
  before(:all) do
    raise "You need to set the MerbfulAuthentication[:user] class to use this spec" unless MA[:user].is_a?(Class)
  end
  
  before(:each) do
    MA[:user].clear_database_table
    @hash = valid_user_hash
    @user = MA[:user].new(@hash)
  end
  
  it "should include MerbfulAuthentication::Adapter::Common mixin" do
    MA[:user].should include(MA::Adapter::Common)  
  end
  
  describe "Fields" do
    
    before(:each) do
      MA[:use_activation] = true
    end
    
    it "should make a valid user" do
      user = MA[:user].new(valid_user_hash)
      user.save
      user.errors.should be_empty
    end
    
    it "should have a login field" do
      user = MA[:user].new
      user.should respond_to(:login)
      user.valid?
      user.errors.on(:login).should_not be_nil
    end
    
    it "should add on some random numbers on the end if the username is already taken" do 
      hash = valid_user_hash.except(:login)
      hash[:email] = "homer@simpsons.com"
      u1 = MA[:user].new(hash)
      u1.save
      u1.should_not be_new_record
      u1.login.should == "homer"

      h2 = valid_user_hash.except(:login)
      h2[:email] = "homer@shelbyvile.com"
      u2 = MA[:user].new(h2)
      u2.save
      u2.should_not be_new_record
      u2.login.should match(/homer\d{3}/)
      u2.login.should == "homer000"

      h3 = valid_user_hash.except(:login)
      h3[:email] = "homer@hotmail.com"
      u3 = MA[:user].new(h3)
      u3.save
      u3.should_not be_new_record
      u3.login.should match(/homer\d{3}/)
      u3.login.should == "homer001"
    end
    
    it "should fail login if there are less than 3 chars" do
      user = MA[:user].new
      user.login = "AB"
      user.valid?
      user.errors.on(:login).should_not be_nil
    end
    
    it "should not fail nickname with between 3 and 40 chars" do
      user = MA[:user].new
      [3,40].each do |num|
        user.login = "a" * num
        user.valid?
        user.errors.on(:login).should be_nil
      end
    end
    
    it "should fail login with over 90 chars" do
      user = MA[:user].new
      user.login = "A" * 41
      user.valid?
      user.errors.on(:login).should_not be_nil    
    end
    
    it "should make sure login is unique regardless of case" do
      MA[:user].find_with_conditions(:login => "Daniel").should be_nil
      user = MA[:user].new( valid_user_hash.with(:login => "Daniel") )
      user2 = MA[:user].new( valid_user_hash.with(:login => "daniel"))
      user.save
      user.should_not be_a_new_record
      user2.save
      user2.should be_a_new_record
      user2.errors.on(:login).should_not be_nil
    end
    
    it "should downcase logins" do
      user = MA[:user].new( valid_user_hash.with(:login => "DaNieL"))
      user.login.should == "daniel"    
    end
    
    it "should authenticate a user using a class method" do
      hash = valid_user_hash
      user = MA[:user].new(hash)
      user.save
      user.should_not be_new_record
      user.activate
      MA[:user].authenticate(hash[:email], hash[:password]).should_not be_nil
    end
    
    it "should not authenticate a user using the wrong password" do
      user = MA[:user].new(valid_user_hash)  
      user.save

      user.activate
      MA[:user].authenticate(valid_user_hash[:email], "not_the_password").should be_nil
    end
    
    it "should not authenticate a user using the wrong login" do
      user = MA[:user].create(valid_user_hash)  

      user.activate
      MA[:user].authenticate("not_the_login@blah.com", valid_user_hash[:password]).should be_nil
    end
    
    it "should not authenticate a user that does not exist" do
      MA[:user].authenticate("i_dont_exist", "password").should be_nil
    end
    
  end
  
  describe "the password fields" do
    
    it "should respond to password" do
      @user.should respond_to(:password)    
    end

    it "should respond to password_confirmation" do
      @user.should respond_to(:password_confirmation)
    end

    it "should respond to crypted_password" do
      @user.should respond_to(:crypted_password)    
    end

    it "should require password if password is required" do
      user = MA[:user].new( valid_user_hash.without(:password))
      user.stub!(:password_required?).and_return(true)
      user.valid?
      user.errors.on(:password).should_not be_nil
      user.errors.on(:password).should_not be_empty
    end

    it "should set the salt" do
      user = MA[:user].new(valid_user_hash)
      user.salt.should be_nil
      user.send(:encrypt_password)
      user.salt.should_not be_nil    
    end

    it "should require the password on create" do
      user = MA[:user].new(valid_user_hash.without(:password))
      user.save
      user.errors.on(:password).should_not be_nil
      user.errors.on(:password).should_not be_empty
    end  

    it "should require password_confirmation if the password_required?" do
      user = MA[:user].new(valid_user_hash.without(:password_confirmation))
      user.save
      (user.errors.on(:password) || user.errors.on(:password_confirmation)).should_not be_nil
    end

    it "should fail when password is outside 4 and 40 chars" do
      [3,41].each do |num|
        user = MA[:user].new(valid_user_hash.with(:password => ("a" * num)))
        user.valid?
        user.errors.on(:password).should_not be_nil
      end
    end

    it "should pass when password is within 4 and 40 chars" do
      [4,30,40].each do |num|
        user = MA[:user].new(valid_user_hash.with(:password => ("a" * num), :password_confirmation => ("a" * num)))
        user.valid?
        user.errors.on(:password).should be_nil
      end    
    end

    it "should autenticate against a password" do
      user = MA[:user].new(valid_user_hash)
      user.save    
      user.should be_authenticated(valid_user_hash[:password])
    end

    it "should not require a password when saving an existing user" do
      hash = valid_user_hash
      user = MA[:user].new(hash)
      user.save
      user.should_not be_a_new_record
      user.login.should == hash[:login].downcase
      user = MA[:user].find_with_conditions(:login => hash[:login].downcase)
      user.password.should be_nil
      user.password_confirmation.should be_nil
      user.login = "some_different_nickname_to_allow_saving"
      (user.save).should be_true
    end
    
  end
  
  describe "activation setup" do
    
    before(:each) do
      MA[:use_activation] = true
    end
    
    it "should have an activation_code as an attribute" do
      @user.attributes.keys.any?{|a| a.to_s == "activation_code"}.should_not be_nil
    end

    it "should create an activation code on create" do
      @user.activation_code.should be_nil    
      @user.save
      @user.activation_code.should_not be_nil
    end

    it "should not be active when created" do
      @user.should_not be_activated
      @user.save
      @user.should_not be_activated    
    end

    it "should respond to activate" do
      @user.should respond_to(:activate)    
    end

    it "should activate a user when activate is called" do
      @user.should_not be_activated
      @user.save
      @user.activate
      @user.should be_activated
      MA[:user].find_with_conditions(:email => @hash[:email]).should be_activated
    end

    it "should should show recently activated when the instance is activated" do
      @user.should_not be_recently_activated
      @user.activate
      @user.should be_recently_activated
    end

    it "should not show recently activated when the instance is fresh" do
      @user.activate
      @user = nil
      MA[:user].find_with_conditions(:email => @hash[:email]).should_not be_recently_activated
    end

    it "should send out a welcome email to confirm that the account is activated" do
      @user.save
      MA[:user_mailer].should_receive(:dispatch_and_deliver) do |action, mail_args, mailer_params|
        action.should == :activation_notification
        mail_args.keys.should include(:from)
        mail_args.keys.should include(:to)
        mail_args.keys.should include(:subject)
        mail_args[:to].should == @user.email
        mailer_params[:user].should == @user
      end
      @user.activate
    end
    
    it "should send a please activate email" do
      user = MA[:user].new(valid_user_hash)
      MA[:user_mailer].should_receive(:dispatch_and_deliver) do |action, mail_args, mailer_params|
        action.should == :signup_notification
        [:from, :to, :subject].each{ |f| mail_args.keys.should include(f)}
        mail_args[:to].should == user.email
        mailer_params[:user].should == user
      end
      user.save
    end
  
    it "should not send a please activate email when updating" do
      user = MA[:user].new(valid_user_hash)
      user.save
      MA[:user].should_not_receive(:signup_notification)
      user.login = "not in the valid hash for nickname"
      user.save    
    end
    
  end
  
end