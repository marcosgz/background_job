# BackgroundJob

The purpose of this gem is to provide a simple way to enqueue background jobs in different background job clientes like Sidekiq, Faktory. (More to come). You can push jobs to the clients without actually have the client installed in your system. This is useful for distributed system or data pipelines where you want to use jobs to communicate between different services.

If you are using a monolithic application, you should use the client directly. Or in a [Ruby on Rails](https://github.com/rails/rails) application consider using [Active Jobs](https://github.com/rails/rails/tree/master/activejob). ActiveJobs integrates with a wider range of services and builtin support.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'background_job'
```

And then execute:

    $ bundle install

Or install it yourself as:

    $ gem install background_job

## Usage

Right now the gem supports Sidekiq and Faktory. Client configurations will be covered in the next section.

You can build and push jobs using a simple DSL. The DSL is the same for all clients, but the configurations may vary.

```ruby
# Enqueue the 'Accounts::ConfirmationEmailWorker' job with 'User', 1 arguments to the sidekiq "high_priority_mailing" queue
BackgroundJob.sidekiq("Accounts::ConfirmationEmailWorker", queue: 'high_priority_mailing').with_args("User", 1).push
```

```ruby
# Schedule the 'Accounts::ConfirmationEmailWorker' job with 'User', 1 arguments to the sidekiq "high_priority_mailing" queue to be executed in one hour.
BackgroundJob.sidekiq("Accounts::ConfirmationEmailWorker", queue: 'high_priority_mailing').with_args("User", 1).in(1.hour).push
```

```ruby
# Enqueue the 'Accounts::ConfirmationEmailWorker' job with 'User', 1 arguments to the faktory "mailing" queue
BackgroundJob.faktory("Accounts::ConfirmationEmailWorker", queue: 'mailing').with_args("User", 1).push
```

DSL Methods:
* `with_args(*args)`: Pass the arguments to the job
* `in(time)`: Schedule the job to be executed in the future. The time can be a `Time`, `DateTime`, `ActiveSupport::Duration` or a number of seconds.
* `with_job_jid(jid)`: Set the job JID. This is useful to track the job status or cancel it. Optional, it will be generated automatically.
* `created_at(time)`: Set the job creation time. Optional, it will be generated automatically.
* `enqueue_at(time)`: Set the job enqueue time.  Optional, it will be generated automatically.
* `push`: Push the job to the client.

### Sidekiq

Sidekiq configurations are under a `BackgroundJob.config.sidekiq` config. You must set the `redis` connection where Sidekiq is running.

```ruby
BackgroundJob.configure do |conf|
  conf.sidekiq.redis = { url: 'redis://localhost:6379/0' } # You can pass the Redis instance directly as well
  # Or using a connection pool
  conf.sidekiq.redis = ConnectionPool.new(size: 5, timeout: 5) do
    Redis.new(url: 'redis://localhost:6379/0')
  end
  # config.sidekiq.namespace = 'sidekiq' # Optional, default is nil in favor of number of databases of Redis
end
```

From an YAML file
```yaml
redis:
  url: 'redis://localhost:6379/0'
jobs:
  UsesJob:
    queue: 'default'
    retry: 3
  BatchImportJob:
    queue: 'import'
    retry: 0
```

```ruby
BackgroundJob.config_for(:sidekiq) do |config|
  config.config_path = 'config/background_job.yml'
end
```

#### Client DSL for Sidekiq to enqueue jobs

If your are using Sidekiq in a service that does not have a jobs/worker defined, you may want to specify the list of jobs and their configurations like `queue` and `retry` in the `BackgroundJob.config.sidekiq.jobs` configuration.

```ruby
BackgroundJob.configure do |conf|
  conf.sidekiq.redis = { url: 'redis://localhost:6379/0' }
  conf.sidekiq.jobs = {
    "UsesJob" { queue: 'default', retry: 3 },
    "BatchImportJob" { queue: 'import', retry: 0 }
  }
  # Default is true true, it means that will raise an error if the job is not defined in the jobs configuration
  # conf.sidekiq.strict = false
end
```

#### Backend Mixins for Sidekiq

This are optional, you can keep your backend implementation in your application according to the client documentation. But if you want to get benefit of global configurations, or custom middlewares, you can use the provided mixins.

```diff
class Accounts::ConfirmationEmailWorker
+  extend BackgroundJob.mixin(:sidekiq, queue: :mailing)
-  include Sidekiq::Worker
-  sidekiq_options queue: :mailing

  def perform(resource_type, resource_id)
    # Do something
  end
end
```

Now when you call `Accounts::ConfirmationEmailWorker.perform_async` or `Accounts::ConfirmationEmailWorker.perform_in` it will use this gem to push jobs to the backend server with the configurations defined in the mixin and the global configurations.

### Faktory

Faktory configurations are under a `BackgroundJob.config.faktory` config. This is in an erly stage. It means that the [faktory_worker_ruby](https://github.com/contribsys/faktory_worker_ruby) gem must be installed in your system.

```ruby
require 'faktory'
BackgroundJob.configure do |conf|
  conf.faktory # Just call it to enable the Faktory client
  # Default is true true, it means that will raise an error if the job is not defined in the jobs configuration
  # conf.faktory.strict = false
end
```

#### Client DSL for Faktory to enqueue jobs

If your are using Faktory in a service that does not have a jobs/worker defined, you may want to specify the list of jobs and their configurations like `queue` and `retry` in the `BackgroundJob.config.faktory.jobs` configuration.

```ruby
BackgroundJob.configure do |conf|
  conf.faktory
  conf.faktory.jobs = {
    "UsesJob" { queue: 'default', retry: 3 },
    "BatchImportJob" { queue: 'import', retry: 0 }
  }
end
```

#### Backend Mixins for Faktory

This are optional, you can keep your backend implementation in your application according to the client documentation. But if you want to get benefit of global configurations, or custom middlewares, you can use the provided mixins.

```diff
class Accounts::ConfirmationEmailWorker
+  extend BackgroundJob.mixin(:faktory, queue: :mailing)
-  include Faktory::Job

  def perform(resource_type, resource_id)
    # Do something
  end
end
```

Now when you call `Accounts::ConfirmationEmailWorker.perform_async` or `Accounts::ConfirmationEmailWorker.perform_in` it will use this gem to push jobs to the backend server with the configurations defined in the mixin and the global configurations.

## Middleware

You can define middlewares to run before and after the job execution. This is useful to add custom logging, error handling, or any other custom behavior. The current version implements a UniqueJob middleware that prevents the job to be enqueued if it is already in the queue. More details in the next section.

This is an example of a minimal middleware, note the method must return the result or the job will not push the server

```ruby
class MyMiddleware
  def call(job, conn_pool)
    puts "Before push"
    result = yield
    puts "After push"
    result
  end
end

BackgroundJob.config_for(:sidekiq) do |config|
  config.middleware do |chain|
    chain.add MyMiddleware
  end
end
```

### Unique Jobs

This library provides one experimental technology to avoid enqueue duplicated jobs. Pro versions of sidekiq and faktory provides this functionality. But this project exposes a mechanism to make this control using `Redis`. It's not loaded by default. You can load this function by require and initialize the `UniqueJob` middleware according to the service(`:faktory` or `:sidekiq`).

```ruby
require 'background_job/middleware/unique_job'
BackgroundJob::Middleware::UniqueJob::bootstrap(service: :sidekiq)
# Or
BackgroundJob::Middleware::UniqueJob::bootstrap(service: :faktory)

# Make sure to add a redis connection to the configuration
BackgroundJob.configure do |conf|
  conf.redis = { url: 'redis://localhost:6379/0' }
  # Or using a connection pool
  conf.redis = ConnectionPool.new(size: 5, timeout: 5) do
    Redis.new(url: 'redis://localhost:6379/0')
  end
end
```

After that just define the `:uniq` settings by worker

```ruby
BackgroundJob.sidekiq('Mailing::SignUpWorker', uniq: { across: :queue, timeout: 120 })
  .with_args('User', 1)
  .push
```

You can globally disable/enable this function with the `BackgroundJob.config.sidekiq.unique_job_active = <true|false>`

## Development

After checking out the repo, run `bin/setup` to install dependencies. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/marcosgz/multi-background-job.


## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
