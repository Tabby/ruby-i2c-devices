# frozen_string_literal: true

require "i2c"
require_relative "ads1013"

class I2CDevice
  # Texas Instruments ADS1014 (Analog-to-Digital converter)
  # https://www.ti.com/lit/gpn/ads1014
  #
  # Only standard (up to 100Kbps) and fast (up to 400Kbps) modes supported.
  # High-speed (up to 3.4Mbps clock) mode support not implemented
  class ADS1014 < I2CDevice::ADS1013
    GAIN_MODE = {
      0b000 => :six_x,
      0b001 => :four_x,
      0b010 => :two_x,
      0b011 => :one_x,
      0b100 => :half_x,
      0b101 => :quarter_X,
      0b110 => :quarter_X,
      0b111 => :quarter_X
    }.freeze

    # Comparator mode
    # ADS1014 & ADS1015 only
    # Controls comparator operating mode
    COMP_MODE = {
      0b0 => :traditional,
      0b1 => :window
    }.freeze

    # Comparator polarity
    # ADS1014 & ADS1015 only
    # Controls polarity of ALERT/RDY pin
    COMP_POL = {
      0b0 => :active_low,
      0b1 => :active_high
    }.freeze

    # Latching comparator
    # ADS1014 & ADS1015 only
    # Control whether to latch the ASSERT/RDY pin high when asserted
    COMP_LAT = {
      0b0 => :non_latching,
      0b1 => :latching
    }.freeze

    # Comparator queue and disable
    # ADS1014 & ADS1015 only
    # Set how many conversions exceeding upper/lower threshold before asserting
    # the ALERT/RDY pin
    COMP_QUE = {
      0b00 => :one_conversion,
      0b01 => :two_conversions,
      0b10 => :three_conversions,
      0b11 => :disable
    }.freeze

    def get_configuration
      response = super
      raw = response[:raw_value]
      {
        input_multiplexer:   MUXER_MODE[(raw[0] >> 4) & 0x07],
        gain_amplifier:      GAIN_MODE[(raw[0] >> 1) & 0x07],
        comparator_mode:     COMP_MODE[(raw[1] >> 4) & 0x01],
        comparator_polarity: COMP_POL[(raw[1] >> 3) & 0x01],
        comparator_latch:    COMP_LAT[(raw[1] >> 2) & 0x01],
        comparator_queue:    COMP_QUE[raw[1] & 0x03]
      }.merge(response)
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
      raise "Invalid value: #{value} - must be -2047 to 2048 (0x7ff to 0x8ff)" unless value < 2049 && value > -2048

      i2cset(
        [
          ADDRESS_POINTER[register],
          (register_value & 0xff00) >> 8,
          register_value & 0xff
        ].pack("s>")
      )
    end

    def get_threshold(register)
      assert_valid_threshold_register(register)

      i2cget(ADDRESS_POINTER[register], 2).unpack("s>") >> 4
    end

    def assert_valid_threshold_register(register)
      raise "Invalid register: #{register}" unless %i[hi_threshold_register lo_threshold_register].include?(register)
    end

    protected

    # Set device configuration register
    # @param args [Hash<Symbol>] parameters to set
    def set_configuration_(args, conf)
      args = {
        # Default values after reset
        gain_amplifier:      :two_x,
        comparator_mode:     :traditional,
        comparator_polarity: :active_low,
        comparator_latch:    :non_latching,
        comparator_queue:    :disable
      }.merge(args)

      @configuration = args

      conf = [
        conf[0] |
          GAIN_MODE.key(args[:gain_amplifier]) << 11,
        conf[1] |
          COMP_MODE.key(args[:comparator_mode]) << 4 |
          COMP_POL.key(args[:comparator_polarity]) << 3 |
          COMP_LAT.key(args[:comparator_latch]) << 2 |
          COMP_QUE.key(args[:comparator_queue])
      ]
      super(args, conf)
    end
  end
end
