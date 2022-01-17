# frozen_string_literal: true

require_relative "constants"

class I2CDevice
  module ADS101x
    class Config
      def self.attr_config(*attrs)
        attrs.each do |attr|
          define_method(attr) do
            instance_variable_get(:@config)[attr]
          end
        end
      end

      attr_config :operational_status,
                  :input_multiplexer,
                  :gain_mode,
                  :operation_mode,
                  :data_rate,
                  :comparator_mode,
                  :comparator_polarity,
                  :comparator_latch,
                  :comparator_queue

      def initialize(device, type: :ads1013, config: {})
        raise "Device cannot be nil" if device.nil?
        raise "Invalid chip type: #{type}" unless %i[ads1013 ads1014 ads1015].include? type

        @device = device
        @type = type
        @config = ADS101x::DEFAULT_CONFIG.merge(config)
      end

      # Reads config values direct from the device
      def read
        response = @device.i2cget(ADS101x::ADDRESS_POINTER[:config_register], 2).unpack("C2")
        @config = ADS101x::DEFAULT_CONFIG.merge(parse_config(response))
        @config
      end

      def set(args)
        args = @config.except(:operational_status).merge(args)

        @device.i2cset(
          ADS101x::ADDRESS_POINTER[:config_register],
          *generate_config(args)
        )
        read
      end

      private

      def generate_config(args)
        @config.keys.each_with_object([0, 0]) do |arg, config|
          bit = ADS101x::CONFIG_BITS[arg]
          value_key = arg == :operational_status && !args.include?(arg) ? :noop : args[arg]
          value = bit[:bit_values][value_key]
          config[bit[:byte]] |= value << bit[:lsb]
          config
        end
      end

      def parse_config(response)
        {
          operational_status:  parse(response, :operational_status),
          input_multiplexer:   parse(response, :input_multiplexer),
          gain_mode:           parse(response, :gain_mode),
          operation_mode:      parse(response, :operation_mode),
          data_rate:           parse(response, :data_rate),
          comparator_mode:     parse(response, :comparator_mode),
          comparator_polarity: parse(response, :comparator_polarity),
          comparator_latch:    parse(response, :comparator_latch),
          comparator_queue:    parse(response, :comparator_queue)
        }
      end

      def parse(response, bit_name)
        bit = ADS101x::CONFIG_BITS[bit_name]
        bit[:values][(response[bit[:byte]] >> bit[:lsb]) & bit[:mask]]
      end
    end
  end
end
