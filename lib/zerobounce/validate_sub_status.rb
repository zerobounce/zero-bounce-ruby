# frozen_string_literal: true

module Zerobounce
  # Validation sub-status values returned by the API (validate, validate_batch).
  # Use for comparison: response['sub_status'] == Zerobounce::ValidateSubStatus::ACCEPT_ALL
  # Unknown/future API values are not listed; compare against response['sub_status'] as string.
  module ValidateSubStatus
    NONE = ''
    ANTISPAM_SYSTEM = 'antispam_system'
    GREYLISTED = 'greylisted'
    MAIL_SERVER_TEMPORARY_ERROR = 'mail_server_temporary_error'
    FORCIBLE_DISCONNECT = 'forcible_disconnect'
    MAIL_SERVER_DID_NOT_RESPOND = 'mail_server_did_not_respond'
    TIMEOUT_EXCEEDED = 'timeout_exceeded'
    FAILED_SMTP_CONNECTION = 'failed_smtp_connection'
    MAILBOX_QUOTA_EXCEEDED = 'mailbox_quota_exceeded'
    EXCEPTION_OCCURRED = 'exception_occurred'
    POSSIBLE_TRAP = 'possible_trap'
    ROLE_BASED = 'role_based'
    GLOBAL_SUPPRESSION = 'global_suppression'
    MAILBOX_NOT_FOUND = 'mailbox_not_found'
    NO_DNS_ENTRIES = 'no_dns_entries'
    FAILED_SYNTAX_CHECK = 'failed_syntax_check'
    POSSIBLE_TYPO = 'possible_typo'
    UNROUTABLE_IP_ADDRESS = 'unroutable_ip_address'
    LEADING_PERIOD_REMOVED = 'leading_period_removed'
    DOES_NOT_ACCEPT_MAIL = 'does_not_accept_mail'
    ALIAS_ADDRESS = 'alias_address'
    ROLE_BASED_CATCH_ALL = 'role_based_catch_all'
    DISPOSABLE = 'disposable'
    TOXIC = 'toxic'
    ALTERNATE = 'alternate'
    MX_FORWARD = 'mx_forward'
    BLOCKED = 'blocked'
    ALLOWED = 'allowed'
    ACCEPT_ALL = 'accept_all'
    ROLE_BASED_ACCEPT_ALL = 'role_based_accept_all'
    GOLD = 'gold'
  end
end
