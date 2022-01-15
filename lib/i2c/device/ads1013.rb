# frozen_string_literal: true

require "i2c"
require "pry"

class I2CDevice
  # Texas Instruments ADS1013 (Analog-to-Digital converter)
  # https://www.ti.com/lit/gpn/ads1013
  #
  # Only standard (up to 100Kbps) and fast (up to 400Kbps) modes supported.
  # High-speed (up to 3.4Mbps clock) mode support not implemented
  class ADS1013 < I2CDevice
    ADDRESS = {
      addr_pin_ground: 0x48, # Default
      addr_pin_vdd:    0x49,
      addr_pin_sda:    0x4a,
      addr_pin_scl:    0x4b
    }.freeze

    OPERATIONAL_STATUS_READ = {
      0b0 => :converting,
      0b1 => :not_converting
    }.freeze

    # Only applicable when in power-down mode
    OPERATIONAL_STATUS_WRITE = {
      noop:           0b0,
      start_one_shot: 0b1
    }.freeze

    OPERATION_MODE = { # :nodoc:
      0b00 => :continuous_conversion,
      0b01 => :one_shot
    }.freeze

    # Data rate in SPS
    DATA_RATE = {
      0b000 => :sps128,
      0b001 => :sps250,
      0b010 => :sps490,
      0b011 => :sps920,
      0b100 => :sps1600,
      0b101 => :sps2400,
      0b110 => :sps3300,
      0b111 => :sps3300
    }.freeze

    attr_reader :configuration

    def initialize(args = { address: ADDRESS[:addr_pin_ground] })
      super(args)
      @configuration = DEFAULT_CONFIGURATION
    end

    # Set device configuration register
    # @param args [Hash<Symbol>] parameters to set
    def set_configuration(args)
      set_configuration_(args, [0, 0])
    end

    def get_configuration
      response = i2cget(ADDRESS_POINTER[:config_register], 2).unpack("C2")
      {
        raw_value:          response[0] << 8 | response[1],
        operational_status: OPERATIONAL_STATUS_READ[(response[0] >> 7) & 0x01],
        operation_mode:     OPERATION_MODE[response[0] & 0x01],
        data_rate:          DATA_RATE[(response[1] >> 5) & 0x07]
      }
    end

    def data_rate
      @configuration[:data_rate].to_s[3..].to_i
    end

    def busy?
      get_configuration[:operational_status] == :converting
    end

    # Sends an I2C general call reset command to all devices on the BUS
    # Causes the device to restart and reset its configuration to default values
    def general_reset
      @driver.i2cset(GENERAL_CALL_ADDRESS, 0x06)
      set_configuration({})
    end

    def one_shot_conversion
      set_configuration({ operation_status: :one_shot })
      sleep 1.0 / data_rate while busy?
      conversion
    end

    # Read the contents of the conversion register
    # @return [Integer] signed 12 bit reading, in mV
    def conversion
      response = i2cget(ADDRESS_POINTER[:conversion_register], 2)
      if response == NEGATIVE_MAX
        -2048
      else
        response.unpack1("s>") >> 4
      end
    end

    protected

    GENERAL_CALL_ADDRESS = 0x0
    NEGATIVE_MAX = [0xff, 0xf0].pack("C*").freeze

    DEFAULT_CONFIGURATION = {
      # Default values after reset
      operational_status: :noop,
      operation_mode:     :one_shot,
      data_rate:          :sps1600
    }.freeze

    ADDRESS_POINTER = {
      conversion_register:   0x00,
      config_register:       0x01,
      lo_threshold_register: 0x02,
      hi_threshold_register: 0x03
    }.freeze

    def set_configuration_(args, conf)
      args = @configuration.merge(args)

      @configuration = args

      conf = [
        ADDRESS_POINTER[:config_register],
        conf[0] |
          OPERATIONAL_STATUS_WRITE[args[:operational_status]] << 7 |
          OPERATION_MODE.key(args[:operation_mode]),
        conf[1] |
          DATA_RATE.key(args[:data_rate]) << 5
      ]
      i2cset(*conf)
    end
  end
end
