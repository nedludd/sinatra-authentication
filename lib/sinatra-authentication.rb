require 'sinatra/base'
require 'pathname'
require Pathname(__FILE__).dirname.expand_path + "models/abstract_user"

module Sinatra
  module LilAuthentication
    def self.registered(app)
      #INVESTIGATE
      #the possibility of sinatra having an array of view_paths to load from
      #PROBLEM
      #sinatra 9.1.1 doesn't have multiple view capability anywhere
      #so to get around I have to do it totally manually by
      #loading the view from this path into a string and rendering it
      set :sinatra_authentication_view_path, Pathname(__FILE__).dirname.expand_path + "views/"

      get '/users' do
        login_required
        redirect "/" unless current_user.admin?

        @users = User.all
        if @users != []
          haml get_view_as_string("index.haml"), :layout => use_layout?
        else
          redirect '/signup'
        end
      end

      get '/users/:id' do
        login_required

        @user = User.get(:id => params[:id])
        haml get_view_as_string("show.haml"), :layout => use_layout?
      end

      #convenience for ajax but maybe entirely stupid and unnecesary
      get '/logged_in' do
        if session[:user]
          "true"
        else
          "false"
        end
      end

      get '/login' do
        haml get_view_as_string("login.haml"), :layout => use_layout?
      end

      post '/login' do
        if user = User.authenticate(params[:email], params[:password])
          session[:user] = user.id

          if Rack.const_defined?('Flash')
            flash[:notice] = "Login successful."
          end

          if session[:return_to]
            redirect_url = session[:return_to]
            session[:return_to] = false
            redirect redirect_url
          else
            redirect '/'
          end
        else
          if Rack.const_defined?('Flash')
            flash[:notice] = "The email or password you entered is incorrect."
          end
          redirect '/login'
        end
      end

      get '/logout' do
        session[:user] = nil
        if Rack.const_defined?('Flash')
          flash[:notice] = "Logout successful."
        end
        redirect '/'
      end

      get '/signup' do
        haml get_view_as_string("signup.haml"), :layout => use_layout?
      end

      post '/signup' do
        @user = User.set(params[:user])
        if @user && @user.id
          session[:user] = @user.id
          if Rack.const_defined?('Flash')
            flash[:notice] = "Account created."
          end
          redirect '/'
        else
          if Rack.const_defined?('Flash')
            flash[:notice] = 'There were some problems creating your account. Please be sure you\'ve entered all your information correctly.'
          end
          redirect '/signup'
        end
      end

      get '/users/:id/edit' do
        login_required
        redirect "/users" unless current_user.admin? || current_user.id.to_s == params[:id]
        @user = User.get(:id => params[:id])
        haml get_view_as_string("edit.haml"), :layout => use_layout?
      end

      post '/users/:id/edit' do
        login_required
        redirect "/users" unless current_user.admin? || current_user.id.to_s == params[:id]

        user = User.get(:id => params[:id])
        user_attributes = params[:user]
        if params[:user][:password] == ""
            user_attributes.delete("password")
            user_attributes.delete("password_confirmation")
        end

        if user.update(user_attributes)
          if Rack.const_defined?('Flash')
            flash[:notice] = 'Account updated.'
          end
          redirect '/'
        else
          if Rack.const_defined?('Flash')
            flash[:notice] = 'Whoops, looks like there were some problems with your updates.'
          end
          redirect "/users/#{user.id}/edit"
        end
      end

      get '/users/:id/delete' do
        login_required
        redirect "/users" unless current_user.admin? || current_user.id.to_s == params[:id]

        if User.delete(params[:id])
          if Rack.const_defined?('Flash')
            flash[:notice] = "User deleted."
          end
        else
          if Rack.const_defined?('Flash')
            flash[:notice] = "Deletion failed."
          end
        end
        redirect '/'
      end
    end
  end

  module Helpers
    def login_required
      #not as efficient as checking the session. but this inits the fb_user if they are logged in
      if current_user.class != GuestUser
        return true
      else
        session[:return_to] = request.fullpath
        redirect '/login'
        return false
      end
    end

    def current_user
      if session[:user]
        User.get(:id => session[:user])
      else
        GuestUser.new
      end
    end

    def logged_in?
      !!session[:user]
    end

    def use_layout?
      !request.xhr?
    end

    #BECAUSE sinatra 9.1.1 can't load views from different paths properly
    def get_view_as_string(filename)
      view = options.sinatra_authentication_view_path + filename
      data = ""
      f = File.open(view, "r")
      f.each_line do |line|
        data += line
      end
      return data
    end

    def render_login_logout(html_attributes = {:class => ""})
    css_classes = html_attributes.delete(:class)
    parameters = ''
    html_attributes.each_pair do |attribute, value|
      parameters += "#{attribute}=\"#{value}\" "
    end

      result = "<div id='sinatra-authentication-login-logout' >"
      if logged_in?
        logout_parameters = html_attributes
        # a tad janky?
        logout_parameters.delete(:rel)
        result += "<a href='/users/#{current_user.id}/edit' class='#{css_classes} sinatra-authentication-edit' #{parameters}>Edit account</a> "
        result += "<a href='/logout' class='#{css_classes} sinatra-authentication-logout' #{logout_parameters}>Logout</a>"
      else
        result += "<a href='/signup' class='#{css_classes} sinatra-authentication-signup' #{parameters}>Signup</a> "
        result += "<a href='/login' class='#{css_classes} sinatra-authentication-login' #{parameters}>Login</a>"
      end

      result += "</div>"
    end
  end

  register LilAuthentication
end

class GuestUser
  def guest?
    true
  end

  def permission_level
    0
  end

  # current_user.admin? returns false. current_user.has_a_baby? returns false.
  # (which is a bit of an assumption I suppose)
  def method_missing(m, *args)
    return false
  end
end
