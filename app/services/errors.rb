module Errors
  class Error < StandardError; end
  class BadRequestError < Error; end
  class InvalidAddressError < Error; end
  class InvalidResponseError < Error; end
  class TimeoutError < Error; end
  class RateLimitError < Error; end
  class UpstreamError < Error; end
end
