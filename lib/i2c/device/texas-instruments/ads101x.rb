# coding: utf-8
# frozen_string_literal: true

require "i2c"

# Texas Instruments ADS1013/ADS1014/ADS1015 (Analog-to-Digital converter)
# https://www.ti.com/lit/gpn/ads1015
#
# Only standard (up to 100Kbps) and fast (up to 400Kbps) modes supported.
# High-speed (up to 3.4Mbps clock) mode support not implemented
class I2CDevice::ADS101x < I2CDevice do
  const GENERAL_CALL_ADDRESS = 0x0.freeze

  const ADDRESS = {
    addr_pin_ground: 0x48, # Default
    addr_pin_vdd:    0x49,
    addr_pin_sda:    0x4a,
    addr_pin_scl:    0x4b
  }.freeze

  attr_reader :configuration

  def initialize(args = { address: ADDRESS[:addr_pin_ground] })
    super
    @address_pointer = nil
    set_configuration({})
  end

  
  # Set device configuration register
  # @param args [Hash<Symbol>] parameters to set
  def set_configuration(args)
    args = {
      # Default values after reset
      operational_status:  :noop,
      input_multiplexer:   :ain0_ain1,
      gain_amplifier:      :two_x,
      operation_mode:      :one_shot,
      data_rate:           :sps_1600,
      comparator_mode:     :traditional,
      comparator_polarity: :active_low,
      comparator_latch:    :non_latching,
      comparator_queue:    :disable,
    }.merge(args)

    @configuration = args

    unless args.empty?
      conf = 
        OPERATIONAL_STATUS_WRITE[args[:operational_status]] << 15 |
				MUXER_MODE.key(args[:input_multiplexer]) << 14 |
				GAIN_MODE.key(args[:gain_amplifier]) << 11 |
				OPERATION_MODE.key(args[:operation_mode]) << 8 |
				DATA_RATE.key(args[:data_rate]) << 7 |
				COMP_MODE.key(args[:comparator_mode]) << 4 |
				COMP_POL.key(args[:comparator_polarity]) << 3 |
				COMP_LAT.key(args[:comparator_latch]) << 2 |
				COMP_QUE.key(args[:comparator_queue])
      set_address_pointer(:config_register)
      i2cset(conf)
    end
  end

  def get_configuration
    response = i2cget(ADDRESS_POINTER]:config_register], 2).unpack("C2")
    {
      operational_status: OPERATIONAL_STATUS_READ[(response[0] >> 7) & 0x01],
      input_multiplexer: MUXER_MODE[(response[0] >> 4) & 0x07],
      gain_amplifier: GAIN_MODE[(response[0] >> 1) & 0x07],
      operation_mode: OPERATION_MODE[(response[0] & 0x01],
      data_rate: DATA_RATE[(response[1] >> 5) & 0x07],
      comparator_mode: COMP_MODE[(response[1] >> 4) & 0x01],
      comparator_mode: COMP_POL[(response[1] >> 3) & 0x01],
      comparator_mode: COMP_LAT[(response[1] >> 2) & 0x01],
      comparator_mode: COMP_QUE[response[1] & 0x03]
    }
  end

  # Sends an I2C general call reset command to all devices on the BUS
  # Causes the device to restart and reset its configuration to default values
  def general_reset
    @driver.i2cset(GENERAL_CALL_ADDRESS, 0x06)
    @address_pointer = nil
    set_configuration({})
  end

	def set_address_pointer(target)
		unless @address_pointer == target
      i2cset(ADDRESS_POINTER[target])
      @address_pointer = target
    end
	end

  def get_value
    i2cget(ADDRESS_POINTER[:conversion_register], 2).unpack("s>") >> 4
  end

  def get_hi_threshold
    get_threshold(:hi_threshold_register)
  end

  def get_lo_threshold
    get_threshold(:lo_threshold_register)
  end

  def set_hi_threshold(value)
    set_threshold(:hi_threshold_register, value)
  end

  def set_lo_threshold(value)
    set_threshold(:lo_threshold_register, value)
  end

  private

  def set_threshold(register, value)
    assert_valid_threshold_register(register)
    raise "Invalid value: #{value} - must be -2047 to 2048 (0x7ff to 0x8ff)" unless value < 2049 && value  > -2048

    i2cset(ADDRESS_POINTER[register], ((value & 0x0fff) << 4).pack("s>"))
  end

  def get_threshold(register)
    assert_valid_threshold_register(register)

    i2cget(ADDRESS_POINTER[register], 2).unpack("s>") >> 4
  end

  def assert_valid_threshold_register(register)
    raise "Invalid register: #{register}" unless register in %i[hi_threshold_register lo_threshold_register]
  end
end

class ADS101x_Constants do
  OPERATIONAL_STATUS_READ = {
    0b0 => :converting,
    0b1 => :not_converting,
  }.freeze

  # Only applicable when in power-down mode
  OPERATIONAL_STATUS_WRITE = {
    :noop           => 0b0,
    :start_one_shot => 0b1,
  }.freeze

  # ADS1015 only
  MUXER_MODE = { # :nodoc:
    0b000 => :ain0_ain1,
    0b001 => :ain0_ain3,
    0b010 => :ain1_ain3,
    0b011 => :ain2_ain3,
    0b100 => :ain0_gnd,
    0b101 => :ain1_gnd,
    0b110 => :ain2_gnd,
    0b111 => :ain3_gnd,
  }.freeze

  # ADS1014 & ADS1015 only
  GAIN_MODE = {
    0b000 => :six_x,
    0b001 => :four_x,
    0b010 => :two_x,
    0b011 => :one_x,
    0b100 => :half_x,
    0b101 => :quarter_X,
    0b110 => :quarter_X,
    0b111 => :quarter_X,
  }.freeze

	OPERATION_MODE = { # :nodoc:
    0b00 => :continuous_conversion,
    0b01 => :one_shot,
  }.freeze

  # Data rate in SPS
  DATA_RATE = {
    0b000 => :sps_128,
    0b001 => :sps_250,
    0b010 => :sps_490,
    0b011 => :sps_920,
    0b100 => :sps_1600,
    0b101 => :sps_2400,
    0b110 => :sps_3300,
    0b111 => :sps_3300,
  }.freeze

  # Comparator mode
  # ADS1014 & ADS1015 only
  # Controls comparator operating mode
  COMP_MODE = {
    0b0 => :traditional,
    0b1 => :window,
  }.freeze

  # Comparator polarity
  # ADS1014 & ADS1015 only
  # Controls polarity of ALERT/RDY pin
  COMP_POL = {
    0b0 => :active_low,
    0b1 => :active_high,
  }.freeze

  # Latching comparator
  # ADS1014 & ADS1015 only
  # Control whether to latch the ASSERT/RDY pin high when asserted
  COMP_LAT = {
    0b0 => :non_latching,
    0b1 => :latching,
  }.freeze

  # Comparator queue and disable
  # ADS1014 & ADS1015 only
  # Set how many conversions exceeding upper/lower threshold before asserting
  # the ALERT/RDY pin
  COMP_QUE = {
    0b00 => :one_conversion,
    0b01 => :two_conversions,
    0b10 => :three_conversions,
    0b11 => :disable,
  }.freeze
    
  ADDRESS_POINTER = {
    conversion_register: 0x00,
    config_register: 0x01,
    lo_threshold_register: 0x02,
    hi_threshold_register: 0x03
  }.freeze

end
