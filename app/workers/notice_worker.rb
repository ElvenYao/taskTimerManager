class NoticeWorker
  include Sidekiq::Worker

  sidekiq_options queue: "notice", retry: false

  def perform(process_id, extra_data)
    Sidekiq.logger.info("----notice worker start----")

    notice = GameManage::Notice.find(process_id)
    unless notice.nil?
      Sidekiq.logger.info(notice["name"])
      if notice.can_online?
        extra_data = JSON.parse(extra_data)
        region_id =  extra_data["region_id"]
        api = extra_data["data"]["api"]
        mailTarget = Target.new('301')
        mailTarget.update_region_id(region_id)
        mailTarget.update_api(api)
        notice.target = mailTarget
        object = notice.attributes.deep_dup
        if object['banner'].blank?
          result_ok,visit_url = "200",""
        else
          result_ok,visit_url = notice.upload_to_s3
        end
        if "200" != result_ok
          flash[:warning] = visit_url
        else
          servers = notice.servers.keys
          result = notice.online!(servers,visit_url)
          SystemLog.create(game: "301", input: notice.contents.to_s, output: result.to_s, controller: "NoticeWorker", action: "NoticeWorker", user: "NoticeWorker")
        end
      else
        Sidekiq.logger.info("#{notice["name"]}不能上线")
      end
    else
      Sidekiq.logger.info("no this task process_id")
    end
    Sidekiq.logger.info("----notice worker end----")
  end

end