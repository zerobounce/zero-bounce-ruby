# frozen_string_literal: true

module Zerobounce
  # API URL constants for Zerobounce endpoints
  #
  # This class provides constant values for different Zerobounce API endpoints
  # that can be accessed publicly by gem users.
  #
  class ApiUrls
    # API URLs
    DEFAULT_URL = 'https://api.zerobounce.net/v2/'
    EU_URL = 'https://api-eu.zerobounce.net/v2/'
    US_URL = 'https://api-us.zerobounce.net/v2/'

    # Bulk API URLs
    BULK_DEFAULT_URL = 'https://bulkapi.zerobounce.net/v2/'

    # The S3 and SFTP/FTP bulk jobs live on the bulkapi host WITHOUT the /v2
    # path. See https://www.zerobounce.net/docs/api-integrations.
    BULK_ROOT_URL = 'https://bulkapi.zerobounce.net/'

    # The list evaluator and the Inbox Placement Tester have their own base
    # URLs, not paths built from the bulk one.
    LIST_EVALUATOR_URL = 'https://bulkapi.zerobounce.net/v2/listevaluator/'
    INBOX_PLACEMENT_URL = 'https://bulkapi.zerobounce.net/api/ipt'
  end
end
