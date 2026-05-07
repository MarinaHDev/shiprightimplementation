module Carrier
  def self.gateway
    @gateway ||= Carrier::Gateway.new
  end

  def self.gateway=(gateway)
    @gateway = gateway
  end

  def self.reset_gateway!
    @gateway = nil
  end
end
