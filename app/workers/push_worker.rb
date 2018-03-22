class PushWorker
  include Sidekiq::Worker

  sidekiq_options queue: "push", retry: false

  def perform(process_id)
    Sidekiq.logger.info("----push worker start----")

    push = GameManage::Push.find(process_id)
    puts push.to_json
    unless push.nil?
      params = {}
      if nil != push then
        Sidekiq.logger.info(push["name"])
        target = Target.new('301')
        arr = push.players.each_slice(1000).to_a
        arr.each do |a|
          params = {
              user_id: a.join(','),
              message: { message: push.message, title: push.title}.to_json
          }

          result, error = target.platform.set_push_msg(params)
          Sidekiq.logger.info("send #{params}")
          inputString = params.clone
          inputString.delete(:user_id)
          inputString[:user_count] = a.length
          SystemLog.create(game: "301", input: inputString.to_s, output: result.to_s, controller: "pushworker", action: "pushworker", user: "pushworker")
          Sidekiq.logger.info("result : #{result}")
          sleep(10)
        end
        push.status = 2
        push.save
      end
    else
      Sidekiq.logger.info("no this task process_id")
    end

    Sidekiq.logger.info("----push worker end----")
  end

end