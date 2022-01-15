#!rspec
# frozen_string_literal: true

$LOAD_PATH.unshift "lib", "."

require 'pry'
require "tempfile"

require "i2c/device/ads1015"
require "i2c/driver/i2c-dev"
require "spec/mocki2cdevice"

describe "I2CDevice::ADS101x" do
	describe I2CDevice::ADS1013 do
    before do
      @mock = MockADS101x.new
      allow(File).to receive(:open) do
        @mock.open
      end
  
      @driver = I2CDevice::Driver::I2CDev.new(@mock.path)
    end

    let(:subject) {
      I2CDevice::ADS1013.new(
        address: I2CDevice::ADS1013::ADDRESS[:addr_pin_ground],
        driver: @driver
      )
    }

    describe "config" do
      it "should read default config" do
        expect(subject.get_configuration).to eq({
          raw_value: 0x8583,
          operational_status: :not_converting,
          operation_mode: :continuous_conversion,
          data_rate: :sps_1600,
        })
      end

      it "should write confid" do
        subject.set_configuration({
          operation_mode: :one_shot,
          data_rate: :sps_128,
        })
        expect(subject.get_configuration).to eq({
          raw_value: 0x8480,
          operational_status: :not_converting,
          operation_mode: :one_shot,
          data_rate: :sps_128,
        })
      end
    end

    # describe "conversions" do
      
    # end
  end
end

#!/usr/bin/env ruby

class MockADS101x < MockI2CDevice
	def initialize()
		super
		@memory = INIITIAL_MEMORY.dup
	end

  def syswrite(buf)
    byte = 0
    buf.unpack("C*").each do |c|
			case @state
			when :init
				@address = c
				@state = (c == 0x0 ? :general_call : :wait)
			when :wait
				@memory[@address][byte] = c
				byte += 1
			when :general_call
				@memory = INIITIAL_MEMORY.dup if c == 0x06 # Reset
        return
			end
		end
	end

	def sysread(size)
		ret = []
    byte = 0
		case @state
		when :init
			raise "Invalid State"
		when :wait
			size.times do
				ret << @memory[@address][byte]
				byte += 1
			end
		end
		ret.pack("C*")
	end

  private
  
  INIITIAL_MEMORY = [
    # conversion
    [0x00, 0x00],
    # config
    [0x85, 0x83],
    # lo thresh
    [0x80, 0x00],
    # hi thresh
    [0x7f, 0xff],
  ].freeze
end
