# frozen_string_literal: true

require "i2c"
require_relative "config"
require_relative "ads1013"

class I2CDevice
  module ADS101x
    # Texas Instruments ADS1014 (Analog-to-Digital converter)
    # https://www.ti.com/lit/gpn/ads1014
    #
    # Only standard (up to 100Kbps) and fast (up to 400Kbps) modes supported.
    # High-speed (up to 3.4Mbps clock) mode support not implemented
    class ADS1014 < I2CDevice::ADS101x::ADS1013
      def initialize(args = { address: ADS101x::ADDRESS[:addr_pin_ground] })
        super(args)
        @configuration = Config.new(self, type: :ads1014)
      end

      def hi_threshold(value = nil)
        threshold(:hi_threshold_register, value)
      end

      def lo_threshold(value = nil)
        threshold(:lo_threshold_register, value)
      end

      def conversion
        raw_value = super
        gain = GAIN[@configuration.gain_mode]
        raw_value * gain
      end

      private

      GAIN = {
        six_V:     3,
        four_V:    2,
        two_V:     1,
        one_V:     0.5,
        half_V:    0.25,
        quarter_V: 0.125
      }.freeze

      def threshold(register, value)
        if value.nil?
          get_threshold(register)
        else
          set_threshold(register, value)
        end
      end

      def set_threshold(register, value)
        assert_valid_threshold_register(register)
        raise "Invalid value: #{value} - must be -2047 to 2048 (0x7ff to 0x8ff)" unless value < 2049 && value > -2048

        i2cset(
          [
            ADS101x::ADDRESS_POINTER[register],
            (register_value & 0xff00) >> 8,
            register_value & 0xff
          ].pack("s>")
        )
      end

      def get_threshold(register)
        assert_valid_threshold_register(register)

        i2cget(ADS101x::ADDRESS_POINTER[register], 2).unpack("s>") >> 4
      end

      def assert_valid_threshold_register(register)
        raise "Invalid register: #{register}" unless %i[hi_threshold_register lo_threshold_register].include?(register)
      end
    end
  end
end
