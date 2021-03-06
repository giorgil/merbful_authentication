require File.dirname(__FILE__) + '/../spec_helper'

describe MA::Sessions, "Index action" do
  
  before(:all) do
    reload_ma!
    Object.class_eval do
      remove_const("User") if defined?(User)
    end
    
    MA[:use_activation] = true
    
    DataMapper.setup(:default, 'sqlite3::memory:')
    Merb.stub!(:orm_generator_scope).and_return("datamapper")
    
    adapter_path = File.join( File.dirname(__FILE__), "..", "..", "lib", "merbful_authentication", "adapters")
    MA.register_adapter :datamapper, "#{adapter_path}/datamapper"
    MA.register_adapter :activerecord, "#{adapter_path}/activerecord"    
    MA.load_slice

    class User
      include MA::Adapter::DataMapper
      include MerbfulAuthentication::Adapter::DataMapper::DefaultModelSetup
    end

  end
  
  before(:each) do
    User.clear_database_table
    u = User.new
    u.valid?
    @quentin = User.create(valid_user_hash.with(:email => "quentin@example.com", :password => "test", :password_confirmation => "test"))
    @controller = MA::Sessions.new(fake_request)
    @quentin.activate
  end
  
  it "should have a route to Sessions#new from '/login'" do
    request_to("/merbful_authentication/login") do |params|
      params[:controller].should == "Sessions"
      params[:action].should == "create"
    end   
  end
  
  it "should route to Sessions#create from '/login' via post" do
    request_to("/merbful_authentication/login", :post) do |params|
      params[:controller].should  == "Sessions"
      params[:action].should      == "create"
    end      
  end
  
  it "should have a named route :login" do
    @controller.url(:merbful_authentication_login).should == "/merbful_authentication/login"
  end
  
  it "should have route to Sessions#destroy from '/logout' via delete" do
    request_to("/merbful_authentication/logout", :delete) do |params|
      params[:controller].should == "Sessions"
      params[:action].should    == "destroy"
    end   
  end
  
  it "should route to Sessions#destroy from '/logout' via get" do
    request_to("/merbful_authentication/logout") do |params|
      params[:controller].should == "Sessions" 
      params[:action].should     == "destroy"
    end
  end

  it 'logins and redirects' do
    controller = post "/merbful_authentication/login", :email => 'quentin@example.com', :password => 'test'
    controller.session[:user].should_not be_nil
    controller.session[:user].should == @quentin.id
    controller.should redirect_to("/")
  end
   
  it 'fails login and does not redirect' do
    controller = post "/merbful_authentication/login", :email => 'quentin@example.com', :password => 'bad password'
    controller.session[:user].should be_nil
    controller.should be_successful
  end

  it 'logs out' do
    controller = get("/merbful_authentication/logout"){|controller| controller.stub!(:current_user).and_return(@quentin) }
    controller.session[:user].should be_nil
    controller.should redirect
  end

  it 'remembers me' do
    controller = post "/merbful_authentication/login", :email => 'quentin@example.com', :password => 'test', :remember_me => "1"
    controller.cookies["auth_token"].should_not be_nil
  end
 
  it 'does not remember me' do
    controller = post "/merbful_authentication/login", :email => 'quentin@example.com', :password => 'test', :remember_me => "0"
    controller.cookies["auth_token"].should be_nil
  end
  
  it 'deletes token on logout' do
    controller = get("/merbful_authentication/logout") {|request| request.stub!(:current_user).and_return(@quentin) }
    controller.cookies["auth_token"].should be_blank
  end
  
  
  it 'logs in with cookie' do
    @quentin.remember_me
    controller = get "/merbful_authentication/login" do |c|
      c.request.env[Merb::Const::HTTP_COOKIE] = "auth_token=#{@quentin.remember_token}"
    end
    controller.should be_logged_in
  end

  def auth_token(token)
    CGI::Cookie.new('name' => 'auth_token', 'value' => token)
  end
    
  def cookie_for(user)
    auth_token user.remember_token
  end
end