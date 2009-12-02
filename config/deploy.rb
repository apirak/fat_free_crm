set :application, "democrm"
set :domain, "#{application}.dooexpert.com"
set :repository,  "git@github.com:apirak/fat_free_crm.git"
set :branch, "i18n"
set :use_sudo, false
set :deploy_to, "/home/femto/www/#{application}"
set :scm, :git

set :keep_releases, 3

set :user, 'femto'
set :ssh_options, {:forward_agent => true}

role :app, domain
role :web, domain
role :db,  domain, :primary => true

namespace :deploy do
  task :start, :roles => :app do
    run "thouch #{current_release}/tmp/restart.txt"
  end 

  task :stop, :roles => :app do
    # Do nothing.
  end

  task :restart, :roles => :app, :except => { :no_release => true } do
    run "touch #{current_release}/tmp/restart.txt"
  end

  task :migrate_setup do
    rake = fetch(:rake, "rake")
    rails_env = fetch(:rails_env, "production")
    migrate_env = fetch(:migrate_env, "")
    migrate_target = fetch(:migrate_target, :latest)

    directory = case migrate_target.to_sym
    when :current then current_path
    when :latest  then current_release
    else 
      raise ArgumentError, "unknown migration target #{migrate_target.inspect}"
    end

    run "mkdir #{shared_path}"
    run "mkdir #{shared_path}/config"
    run "mkdir #{shared_path}/avatars"
    run "mkdir #{shared_path}/log"
    run "mkdir #{shared_path}/pid"

    run "cp #{directory}/config/database.mysql.yml #{shared_path}/config/database.yml"
    run "sed 's/fat_free_crm/#{application}/g' #{shared_path}/config/database.yml > #{shared_path}/config/database.tmp.yml"
    run "mv #{shared_path}/config/database.tmp.yml #{shared_path}/config/database.yml"
    run "sed 's/socket: \\/tmp\\/mysql.sock/host: localhost/g' #{shared_path}/config/database.yml > #{shared_path}/config/database.tmp.yml"
    run "mv #{shared_path}/config/database.tmp.yml #{shared_path}/config/database.yml"

    run "ln -nfs #{shared_path}/config/database.yml #{directory}/config/database.yml"
    run "rm -rf #{directory}/public/avatars"
    run "rm -rf #{directory}/public/stylesheets/cache/all.css"
    run "rm -rf #{directory}/public/stylesheets/cache/screen.css"
    run "ln -nfs #{shared_path}/avatars #{directory}/public/avatars"
    
    run "cd #{directory}; #{rake} RAILS_ENV=#{rails_env} #{migrate_env} db:create"
    run "cd #{directory}; #{rake} RAILS_ENV=#{rails_env} #{migrate_env} db:migrate:reset"
    run "cd #{directory}; #{rake} RAILS_ENV=#{rails_env} #{migrate_env} crm:settings:load"
  end

  task :symlink_shared do
    directory = release_path
    run "ln -nfs #{shared_path}/config/database.yml #{directory}/config/database.yml"
    run "rm -rf #{directory}/public/avatars"
    run "rm -rf #{directory}/public/stylesheets/cache/all.css"
    run "rm -rf #{directory}/public/stylesheets/cache/screen.css"
    run "ln -nfs #{shared_path}/avatars #{directory}/public/avatars"
  end
end

after 'deploy:update_code', 'deploy:symlink_shared'

# First time
# $ cap deploy
# $ cap deploy:migrate_setup

# Setup admin > Server
# $ cd <current>
# $ rake crm:setup:admin RAILS_ENV=production

# Setup demo site
# $ cd <current>
# $ rake crm:demo:load RAILS_ENV=production

# Next time update
# $ cap deploy:update