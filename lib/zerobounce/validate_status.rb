# frozen_string_literal: true

module Zerobounce
  # Validation status values returned by the API (validate, validate_batch).
  # Use for comparison: response['status'] == Zerobounce::ValidateStatus::VALID
  # Unknown/future API values are not listed; compare against response['status'] as string.
  module ValidateStatus
    NONE = ''
    VALID = 'valid'
    INVALID = 'invalid'
    CATCH_ALL = 'catch-all'
    UNKNOWN = 'unknown'
    SPAMTRAP = 'spamtrap'
    ABUSE = 'abuse'
    DO_NOT_MAIL = 'do_not_mail'
  end
end
