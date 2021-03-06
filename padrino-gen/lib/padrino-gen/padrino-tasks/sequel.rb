if PadrinoTasks.load?(:sequel, defined?(Sequel))
  namespace :sq do
    namespace :migrate do
      desc "Perform automigration (reset your db data)"
      task :auto => :skeleton do
        ::Sequel.extension :migration
        ::Sequel::Migrator.run Sequel::Model.db, "db/migrate", :target => 0
        ::Sequel::Migrator.run Sequel::Model.db, "db/migrate"
        puts "<= sq:migrate:auto executed"
      end

      desc "Perform migration up/down to VERSION"
      task :to, [:version] => :skeleton do |t, args|
        version = (args[:version] || ENV['VERSION']).to_s.strip
        ::Sequel.extension :migration
        raise "No VERSION was provided" if version.empty?
        ::Sequel::Migrator.apply(Sequel::Model.db, "db/migrate", version.to_i)
        puts "<= sq:migrate:to[#{version}] executed"
      end

      desc "Perform migration up to latest migration available"
      task :up => :skeleton do
        ::Sequel.extension :migration
        ::Sequel::Migrator.run Sequel::Model.db, "db/migrate"
        puts "<= sq:migrate:up executed"
      end

      desc "Perform migration down (erase all data)"
      task :down => :skeleton do
        ::Sequel.extension :migration
        ::Sequel::Migrator.run Sequel::Model.db, "db/migrate", :target => 0
        puts "<= sq:migrate:down executed"
      end
    end

    desc "Perform migration up to latest migration available"
    task :migrate => 'sq:migrate:up'

    desc "Create the database"
    task :create => :skeleton do
      config = Sequel::Model.db.opts
      user, password, host = config[:user], config[:password], config[:host]
      database = config[:database]
      charset = config[:charset] || ENV['CHARSET']   || 'utf8'
      collation = config[:collation] || ENV['COLLATION'] || 'utf8_unicode_ci'

      puts "=> Creating database '#{database}'"
      if config[:adapter] == 'sqlite3'
        ::Sequel.sqlite(database)
      else
        require 'padrino-gen/padrino-tasks/sql-helpers'
        Padrino::Generators::SqlHelpers.create_db(config[:adapter], user, password, host, database, charset, collation)
      end
      puts "<= sq:create executed"
    end

    desc "Drop the database (postgres and mysql only)"
    task :drop => :skeleton do
      config = ::Sequel::Model.db.opts
      user, password, host, database = config[:user], config[:password], config[:host], config[:database]

      ::Sequel::Model.db.disconnect

      puts "=> Dropping database '#{database}'"
      if config[:adapter] == 'sqlite3'
        File.delete(database) if File.exist?(database)
      else
        Padrino::Generators::SqlHelpers.drop_db(config[:adapter], user, password, host, database)
      end
      puts "<= sq:drop executed"
    end

    desc 'Drop the database, migrate from scratch and initialize with the seed data'
    task :reset => ['drop', 'create', 'migrate', 'seed']

    task :seed => :environment do
      missing_model_features = Padrino.send(:default_dependency_paths) - Padrino.send(:dependency_paths)
      Padrino.require_dependencies(missing_model_features)
      Rake::Task['db:seed'].invoke
    end
  end

  task 'db:migrate' => 'sq:migrate'
  task 'db:reset' => 'sq:reset'
end
