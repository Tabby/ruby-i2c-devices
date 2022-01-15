# frozen_string_literal: true

require "i2c"
require_relative "ads1014"

class I2CDevice
  # Texas Instruments ADS1015 (Analog-to-Digital converter)
  # https://www.ti.com/lit/gpn/ads1015
  #
  # Only standard (up to 100Kbps) and fast (up to 400Kbps) modes supported.
  # High-speed (up to 3.4Mbps clock) mode support not implemented
  class ADS1015 < I2CDevice::ADS1014
    # ADS1015 only
    MUXER_MODE = { # :nodoc:
      0b000 => :ain0_ain1,
      0b001 => :ain0_ain3,
      0b010 => :ain1_ain3,
      0b011 => :ain2_ain3,
      0b100 => :ain0_gnd,
      0b101 => :ain1_gnd,
      0b110 => :ain2_gnd,
      0b111 => :ain3_gnd
    }.freeze

    # Set device configuration register
    # @param args [Hash<Symbol>] parameters to set
    def set_configuration(args)
      args = {
        # Default values after reset
        input_multiplexer: :ain0_ain1
      }.merge(args)

      @configuration = args

      conf = [MUXER_MODE.key(args[:input_multiplexer]) << 14, 0]
      super(args, conf)
    end

    def get_configuration
      response = super
      raw = response[:raw_value]
      {
        input_multiplexer: MUXER_MODE[(raw[0] >> 4) & 0x07]
      }.merge(response)
    end
  end
end
