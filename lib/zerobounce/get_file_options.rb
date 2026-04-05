# frozen_string_literal: true

module Zerobounce
  # Optional query parameters for bulk getfile.
  # +activity_data+ applies to validation +validate_file_get+ only; scoring getfile does not send it.
  class GetFileOptions
    attr_accessor :download_type, :activity_data

    def initialize(download_type: nil, activity_data: nil)
      @download_type = download_type
      @activity_data = activity_data
    end
  end
end
