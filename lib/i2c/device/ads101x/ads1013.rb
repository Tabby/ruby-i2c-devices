# frozen_string_literal: true

require "i2c"
require_relative "config"

class I2CDevice
  module ADS101x
    # Texas Instruments ADS1013 (Analog-to-Digital converter)
    # https://www.ti.com/lit/gpn/ads1013
    #
    # Only standard (up to 100Kbps) and fast (up to 400Kbps) modes supported.
    # High-speed (up to 3.4Mbps clock) mode support not implemented
    class ADS1013 < I2CDevice
      def initialize(args = { address: ADS101x::ADDRESS[:addr_pin_ground] })
        super(args)
        @configuration = Config.new(self)
      end

      # Get/Set device configuration register
      # @param args [Hash<Symbol>] parameters to set
      def configuration(refresh_from_device: false, **args)
        if args.empty?
          @configuration.read if refresh_from_device

          @configuration
        else
          @configuration.set(args)
        end
      end

      def busy?
        configuration(refresh_from_device: true).operational_status == :converting
      end

      # Sends an I2C general call reset command to all devices on the BUS
      # Causes the device to restart and reset its configuration to default values
      def general_reset
        @driver.i2cset(GENERAL_CALL_ADDRESS, 0x06)
        @configuration = Config.new(self)
      end

      def one_shot_conversion
        set_configuration({ operation_status: :one_shot })
        sleep 1.0 / data_rate while busy?
        conversion
      end

      # Read the contents of the conversion register
      # @return [Integer] signed 12 bit reading, in mV
      def conversion
        response = i2cget(ADS101x::ADDRESS_POINTER[:conversion_register], 2)
        if response == NEGATIVE_MAX
          -2048
        else
          response.unpack1("s>") >> 4
        end
      end
    end
  end
end
