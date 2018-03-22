TaskTimer Manager
================

[![Gem Version](https://badge.fury.io/rb/sidekiq.svg)](https://rubygems.org/gems/sidekiq)

# TaskTimerManager
Simple, efficient background processing for Ruby.

Sidekiq uses threads to handle many jobs at the same time in the
same process.  It does not require Rails but will integrate tightly with
Rails to make background processing dead simple.

So the TaskTimer Manager builded on sidekiq, it can make some dynamic schedule to 
do some tasks you need just like crontab.


Requirements
-----------------

Sidekiq supports CRuby 2.2.2+ and JRuby 9k.

All Rails releases >= 4.0 are officially supported.

Redis 2.8 or greater is required.  3.0.3+ is recommended for large
installations with thousands of worker threads.


Installation
-----------------

``` shell
gem install sidekiq
gem install sidekiq-scheduler
```


Usage
-----------------

``` ruby
# time_manager_worker.rb

require 'sidekiq'
require 'sidekiq-scheduler'

class TimeManagerWorker
  include Sidekiq::Worker

  sidekiq_options queue: "time_manager", retry: false

  def perform(id=nil, setOnline=false, type="at", crontime=nil)
    unless id.blank?
      if setOnline
        Sidekiq.logger.info("===create task: task#{id}===")
        Sidekiq.set_schedule("task#{id}", { type=> crontime, 'class' => 'TaskTimeWorker', 'queue' => 'task_time'})
      else
        Sidekiq.logger.info("===delete task: task#{id}===")
        Sidekiq.set_schedule("task#{id}", { 'enabled' => false})
      end
    else
      Sidekiq.logger.info("=======clear outtime start========")
      nowday = Time.new.strftime("%Y-%m-%d %H:%M")
      delete_timer_task = TimerTask.all.where("end_date <= ? and status= 1 and cron_type = 'cron'", nowday).to_a
      delete_timer_task.each do |task|
          Sidekiq.logger.info("task#{task.id} time out")
          Sidekiq.set_schedule("task#{task.id}", { 'enabled' => false})
          task.status = 3
          task.save
      end
      Sidekiq.logger.info("=======clear outtime end========")
      Sidekiq.logger.info("Clear all outtime")

      Sidekiq.logger.info("=======restart tasks start========")
      restart_timer_task = TimerTask.all.where("status= 1").to_a
      restart_timer_task.each do |r_task|
        self.perform(r_task.id, true, r_task.cron_type, r_task.cron_str)
        Sidekiq.logger.info("task#{r_task.id} restart")
      end
      Sidekiq.logger.info("=======restart tasks start========")

    end
    Sidekiq.logger.info(Sidekiq.get_schedule)
  end
end

```
In this file, you can use <I>TimeManagerWorker.perform_async()</I> to add task in quene and write the task information to your database 
where you can find it out to cancle. 

The follow codes is how to create a simple taks table in mysql:
``` mysql
CREATE TABLE `timer_tasks` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `task_type` varchar(50) COLLATE utf8_unicode_ci DEFAULT NULL,
  `cron_type` varchar(50) COLLATE utf8_unicode_ci DEFAULT NULL,
  `cron_str` varchar(50) COLLATE utf8_unicode_ci DEFAULT NULL,
  `cron_times` int(11) DEFAULT '1',
  `process_id` int(11) DEFAULT NULL,
  `status` int(11) DEFAULT '0',
  `start_date` datetime DEFAULT NULL,
  `end_date` datetime DEFAULT NULL,
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime DEFAULT NULL,
  `extra_data` text COLLATE utf8_unicode_ci,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=14 DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;
```


``` ruby
# task_time_worker.rb

require 'sidekiq'
require 'sidekiq-scheduler'

class TaskTimeWorker
  include Sidekiq::Worker

  sidekiq_options queue: "task_time", retry: false
  # schedule = []
  def perform
    time = Time.new
    selectTime = time.strftime("%Y-%m-%d %H:%M")
    time = time + 60
    selectTime1 = time.strftime("%Y-%m-%d %H:%M")
    timer_task = nil
    timer_task = TimerTask.lock.all.where('start_date between ? and ? and status= 1', selectTime, selectTime1).first
    if timer_task.nil?
      timer_task = TimerTask.lock.all.where("start_date <= ? and end_date >= ? and status= 1 and cron_type = 'cron'", selectTime, selectTime1).first
    end
    Sidekiq.logger.info(timer_task.to_json)
    unless timer_task.nil?
      case timer_task.task_type
        when "push"
          Sidekiq.logger.info('------pushtimer start-----')
          Sidekiq.logger.info(timer_task.process_id)
          PushWorker.perform_async(timer_task.process_id)
          Sidekiq.logger.info( '------pushtimer end-----')

        when "notice"
          Sidekiq.logger.info('------noticetimer start-----')
          Sidekiq.logger.info(timer_task.process_id)
          NoticeWorker.perform_async(timer_task.process_id, timer_task.extra_data)
          Sidekiq.logger.info( '------noticetimer end-----')

        else
          Sidekiq.logger.info("no exist task type")
      end
      timer_task.cron_times=timer_task.cron_times-1
      if timer_task.cron_times == 0
        timer_task.status = 2
        TimeManagerWorker.perform_async(timer_task.id, false)
      end
      timer_task.save
    else
      Sidekiq.logger.info("no")
    end
  end
end

```
In this worker, it a timer to execute the task at time.



``` yaml
# config/timer_manager.yml

:dynamic: true
:schedule:
  time_manager:
    cron: '0 0 1 * * *'   # Runs once per day
    class: TimeManagerWorker
:queues:
    - [time_manager, 1]
    - [task_time, 3]
    - [push, 2]
    - [notice, 2]
development:
  :concurrency: 1
staging:
  :concurrency: 1
production:
  :concurrency: 2
:pidfile: tmp/pids/timer_manager.pid
:logfile: log/sidekiq_timer_manager.log
```

Run sidekiq:

``` sh
bundle exec sidekiq -C config/sidekiq/timer_manager.yml

```
or you can code in your shell
``` sh
bundle exec sidekiq -dc 6 -e $environment -P tmp/pids/sidekiq_my.pid -C config/sidekiq/timer_manager.yml -L log/sidekiq_timer_manager.log
```



Thanks
-----------------

You can find the more information about these tools
[sidekiq-scheduler](https://github.com/moove-it/sidekiq-scheduler) 
[sidekiq](https://github.com/moove-it/sidekiq-scheduler)
[redis](https://redis.io/)


License
-----------------

Please see [LICENSE](https://github.com/mperham/sidekiq/blob/master/LICENSE) for licensing details.


Author
-----------------

ElvenYao, [@ElvenYao](http://52Elven.com)