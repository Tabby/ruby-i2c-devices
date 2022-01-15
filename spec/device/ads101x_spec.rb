#!rspec
# frozen_string_literal: true

$LOAD_PATH.unshift "lib", "."

require "pry"
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

    let(:subject) do
      I2CDevice::ADS1013.new(
        address: I2CDevice::ADS1013::ADDRESS[:addr_pin_ground],
        driver:  @driver
      )
    end

    context "config" do
      it "should read default config" do
        expect(subject.get_configuration).to eq(
          {
            raw_value:          0x8583,
            operational_status: :not_converting,
            operation_mode:     :one_shot,
            data_rate:          :sps1600
          }
        )
      end

      it "should write config" do
        subject.set_configuration(
          {
            operation_mode: :one_shot,
            data_rate:      :sps250
          }
        )
        expect(subject.get_configuration).to eq(
          {
            raw_value:          0x0120,
            operational_status: :converting,
            operation_mode:     :one_shot,
            data_rate:          :sps250
          }
        )
      end
    end

    context "conversions" do
      it "should read initial value" do
        expect(subject.conversion).to eq 0
      end

      it "should give correct readings" do
        @mock.memory[0] = [0x7f, 0xf0]
        expect(subject.conversion).to eq 2047

        @mock.memory[0] = [0x1e, 0x20]
        expect(subject.conversion).to eq 482

        @mock.memory[0] = [0x00, 0xb0]
        expect(subject.conversion).to eq 11

        @mock.memory[0] = [0xff, 0xf0]
        expect(subject.conversion).to eq(-2048)

        @mock.memory[0] = [0xe1, 0xe0]
        expect(subject.conversion).to eq(-482)

        @mock.memory[0] = [0xff, 0xa0]
        expect(subject.conversion).to eq(-6)
      end
    end
  end
end

# !/usr/bin/env ruby

class MockADS101x < MockI2CDevice
  def initialize
    super
    @memory = INIITIAL_MEMORY.dup
  end

  def ioctl(cmd, arg)
    @ioctl = [cmd, arg]
    @state = :general_call if arg == 0x00
    self
  end

  def syswrite(buf)
    byte = 0
    buf.unpack("C*").each do |c|
      case @state
      when :init
        @address = c
        @state = :wait
      when :wait
        @memory[@address][byte] = c
        byte += 1
      when :general_call
        @memory = INIITIAL_MEMORY.dup if c == 0x06 # Reset
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

  INIITIAL_MEMORY = [
    # conversion
    [0x00, 0x00],
    # config
    [0x85, 0x83],
    # lo thresh
    [0x80, 0x00],
    # hi thresh
    [0x7f, 0xff]
  ].freeze
end
