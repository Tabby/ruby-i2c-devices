# frozen_string_literal: true

class I2CDevice
  module ADS101x
    ADDRESS = {
      addr_pin_ground: 0x48, # Default
      addr_pin_vdd:    0x49,
      addr_pin_sda:    0x4a,
      addr_pin_scl:    0x4b
    }.freeze

    GENERAL_CALL_ADDRESS = 0x0
    NEGATIVE_MAX = [0xff, 0xf0].pack("C*").freeze

    ADDRESS_POINTER = {
      conversion_register:   0x00,
      config_register:       0x01,
      lo_threshold_register: 0x02,
      hi_threshold_register: 0x03
    }.freeze

    OP_STATUS_READ = {
      0b0 => :converting,
      0b1 => :not_converting
    }.freeze

    # Only applicable when in power-down mode
    OP_STATUS_WRITE = {
      noop:           0b0,
      converting:     0b0, # kludge
      start_one_shot: 0b1,
      not_converting: 0b1 # kludge
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
      0b111 => :ain3_gnd
    }.freeze

    GAIN_MODE = {
      0b000 => :six_V,
      0b001 => :four_V,
      0b010 => :two_V,
      0b011 => :one_V,
      0b100 => :half_V,
      0b101 => :quarter_V,
      0b110 => :quarter_V,
      0b111 => :quarter_V
    }.freeze

    OP_MODE = { # :nodoc:
      0b00 => :continuous,
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

    DEFAULT_CONFIG = {
      # Default values after reset
      operational_status:  :not_converting,
      input_multiplexer:   :ain0_ain1,      # ADS1015 only
      gain_mode:           :two_V,          # ADS1014/ADS1015 only
      operation_mode:      :one_shot,
      data_rate:           :sps1600,
      comparator_mode:     :traditional,    # ADS1014/ADS1015 only
      comparator_polarity: :active_low,     # ADS1014/ADS1015 only
      comparator_latch:    :non_latching,   # ADS1014/ADS1015 only
      comparator_queue:    :disable         # ADS1014/ADS1015 only
    }.freeze

    CONFIG_BITS = {
      operational_status:  { byte: 0, lsb: 7, mask: 0x01, values: OP_STATUS_READ, bit_values: OP_STATUS_WRITE},
      input_multiplexer:   { byte: 0, lsb: 4, mask: 0x07, values: MUXER_MODE, bit_values: MUXER_MODE.invert},
      gain_mode:           { byte: 0, lsb: 1, mask: 0x07, values: GAIN_MODE, bit_values: GAIN_MODE.invert},
      operation_mode:      { byte: 0, lsb: 0, mask: 0x01, values: OP_MODE, bit_values: OP_MODE.invert},
      data_rate:           { byte: 1, lsb: 5, mask: 0x07, values: DATA_RATE, bit_values: DATA_RATE.invert},
      comparator_mode:     { byte: 1, lsb: 4, mask: 0x01, values: COMP_MODE, bit_values: COMP_MODE.invert},
      comparator_polarity: { byte: 1, lsb: 3, mask: 0x01, values: COMP_POL, bit_values: COMP_POL.invert},
      comparator_latch:    { byte: 1, lsb: 2, mask: 0x01, values: COMP_LAT, bit_values: COMP_LAT.invert},
      comparator_queue:    { byte: 1, lsb: 0, mask: 0x03, values: COMP_QUE, bit_values: COMP_QUE.invert}
    }.freeze
  end
end
