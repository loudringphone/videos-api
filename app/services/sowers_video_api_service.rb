class SowersVideoApiService
  include HTTParty

  def get_videos_for_completed_missions
    url ="#{ENV['PRODUCTION_HOST']}/api/presentations/get_videos_for_completed_missions_without_youtube_id?api_key=#{ENV['SOWERS_API']}"
    response = HTTParty.get(url)

    if response.success?
      videos = JSON.parse(response.body)
      videos.map do |video|
        service = Videos::CreateOrUpdate.new(video)
        if service.perform

        end
      end
    else
      raise "Error fetching data: #{response.code} - #{response.message}"
    end

    Video.not_downloaded.each do |video|
      file_path = VideoDownloaderService.new(video).download
      if file_path
        video.update(download_directory: file_path, is_downloaded: true)
        puts "Video for presentation_id: #{video.presentation_id} updated in the database(is_downloaded: true)"
      else
        puts "Failed to download video for presentation_id: #{video.presentation_id}. Shutting down the server..."
        Rails.logger.error("Failed to download video for presentation_id: #{video.presentation_id}. Shutting down the server...")
        exit(1)
      end
    end

    youtube_upload_scope = 'youtube.upload'
    auth_url = Yt::Account.new(scopes: [youtube_upload_scope], redirect_uri: ENV['GOOGLE_OAUTH2_CALLBACK_URL']).authentication_url
    Launchy.open(auth_url)
  end
end