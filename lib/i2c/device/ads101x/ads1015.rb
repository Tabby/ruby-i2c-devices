# frozen_string_literal: true

require "i2c"
require_relative "config"
require_relative "ads1014"

class I2CDevice
  module ADS101x
    # Texas Instruments ADS1015 (Analog-to-Digital converter)
    # https://www.ti.com/lit/gpn/ads1015
    #
    # Only standard (up to 100Kbps) and fast (up to 400Kbps) modes supported.
    # High-speed (up to 3.4Mbps clock) mode support not implemented
    class ADS1015 < I2CDevice::ADS101x::ADS1014
      def initialize(args = { address: ADS101x::ADDRESS[:addr_pin_ground] })
        super(args)
        @configuration = Config.new(self, type: :ads1015)
      end
    end
  end
end
