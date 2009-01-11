module Jpmobile::Mobile
  class Iphone < AbstractMobile
    autoload :IP_ADDRESSES, 'jpmobile/mobile/z_ip_addresses_softbank'

    USER_AGENT_REGEXP = /^Mozilla\/5.0 \(iP(hone|od).*AppleWebKit\/.*Mobile\//

    def supports_cookie?
      true
    end

    def iphone?
      true
    end
  end
end

