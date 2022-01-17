#!rspec
# frozen_string_literal: true

$LOAD_PATH.unshift "lib", "."

require "pry"
require "tempfile"

require "i2c/device/ads101x/ads1015"
require "i2c/driver/i2c-dev"
require "spec/mocki2cdevice"

describe do
  describe I2CDevice::ADS101x::ADS1013 do
    before do
      @mock = MockADS101x.new
      allow(File).to receive(:open) do
        @mock.open
      end
  
      @driver = I2CDevice::Driver::I2CDev.new(@mock.path)
    end

    let(:subject) do
      I2CDevice::ADS101x::ADS1013.new(
        address: I2CDevice::ADS101x::ADDRESS[:addr_pin_ground],
        driver:  @driver
      )
    end

    context "config" do
      it "should read default config" do
        expect(subject.configuration.operational_status).to eq :not_converting
        expect(subject.configuration.operation_mode).to eq :one_shot
        expect(subject.configuration.data_rate).to eq :sps1600
      end

      it "should write config" do
        subject.configuration(
          {
            operation_mode: :one_shot,
            data_rate:      :sps250
          }
        )
        expect(subject.configuration.operational_status).to eq :converting
        expect(subject.configuration.operation_mode).to eq :one_shot
        expect(subject.configuration.data_rate).to eq :sps250
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

  describe I2CDevice::ADS101x::ADS1014 do
    before do
      @mock = MockADS101x.new
      allow(File).to receive(:open) do
        @mock.open
      end
  
      @driver = I2CDevice::Driver::I2CDev.new(@mock.path)
    end

    let(:subject) do
      I2CDevice::ADS101x::ADS1014.new(
        address: I2CDevice::ADS101x::ADDRESS[:addr_pin_ground],
        driver:  @driver
      )
    end

    context "config" do
      it "should read default config" do
        expect(subject.configuration.operational_status).to eq :not_converting
        expect(subject.configuration.gain_mode).to eq :two_V
        expect(subject.configuration.operation_mode).to eq :one_shot
        expect(subject.configuration.data_rate).to eq :sps1600
        expect(subject.configuration.comparator_mode).to eq :traditional
        expect(subject.configuration.comparator_polarity).to eq :active_low
        expect(subject.configuration.comparator_latch).to eq :non_latching
        expect(subject.configuration.comparator_queue).to eq :disable
      end

      it "should write config" do
        subject.configuration(
          {
            operational_status:  :noop,
            gain_mode:           :four_V,
            operation_mode:      :continuous,
            data_rate:           :sps490,
            comparator_mode:     :window,
            comparator_polarity: :active_high,
            comparator_latch:    :latching,
            comparator_queue:    :one_conversion
          }
        )
        expect(subject.configuration.operational_status).to eq :converting
        expect(subject.configuration.gain_mode).to eq :four_V
        expect(subject.configuration.operation_mode).to eq :continuous
        expect(subject.configuration.data_rate).to eq :sps490
        expect(subject.configuration.comparator_mode).to eq :window
        expect(subject.configuration.comparator_polarity).to eq :active_high
        expect(subject.configuration.comparator_latch).to eq :latching
        expect(subject.configuration.comparator_queue).to eq :one_conversion
      end
    end

    context "conversions" do
      it "should read initial value" do
        expect(subject.conversion).to eq 0
      end

      context "FSR +/- 6144mV" do
        before do
          subject.configuration({ gain_mode: :six_V })
        end

        it "should give correct readings" do
          @mock.memory[0] = [0x7f, 0xf0]
          expect(subject.conversion).to eq 6141
          @mock.memory[0] = [0x00, 0xb0]
          expect(subject.conversion).to eq 33
  
          @mock.memory[0] = [0xff, 0xf0]
          expect(subject.conversion).to eq(-6144)
          @mock.memory[0] = [0xff, 0xa0]
          expect(subject.conversion).to eq(-18)
        end
      end

      context "FSR +/- 4096mV" do
        before do
          subject.configuration({ gain_mode: :four_V })
        end

        it "should give correct readings" do
          @mock.memory[0] = [0x7f, 0xf0]
          expect(subject.conversion).to eq 4094
          @mock.memory[0] = [0x00, 0xb0]
          expect(subject.conversion).to eq 22
  
          @mock.memory[0] = [0xff, 0xf0]
          expect(subject.conversion).to eq(-4096)
          @mock.memory[0] = [0xff, 0xa0]
          expect(subject.conversion).to eq(-12)
        end
      end

      context "FSR +/- 2048mV" do
        before do
          subject.configuration({ gain_mode: :two_V })
        end

        it "should give correct readings" do
          @mock.memory[0] = [0x7f, 0xf0]
          expect(subject.conversion).to eq 2047
          @mock.memory[0] = [0x00, 0xb0]
          expect(subject.conversion).to eq 11
  
          @mock.memory[0] = [0xff, 0xf0]
          expect(subject.conversion).to eq(-2048)
          @mock.memory[0] = [0xff, 0xa0]
          expect(subject.conversion).to eq(-6)
        end
      end

      context "FSR +/- 1024mV" do
        before do
          subject.configuration({ gain_mode: :one_V })
        end

        it "should give correct readings" do
          @mock.memory[0] = [0x7f, 0xf0]
          expect(subject.conversion).to eq 1023.5
          @mock.memory[0] = [0x00, 0xb0]
          expect(subject.conversion).to eq 5.5
  
          @mock.memory[0] = [0xff, 0xf0]
          expect(subject.conversion).to eq(-1024.0)
          @mock.memory[0] = [0xff, 0xa0]
          expect(subject.conversion).to eq(-3.0)
        end
      end

      context "FSR +/- 512mV" do
        before do
          subject.configuration({ gain_mode: :half_V })
        end

        it "should give correct readings" do
          @mock.memory[0] = [0x7f, 0xf0]
          expect(subject.conversion).to eq 511.75
          @mock.memory[0] = [0x00, 0xb0]
          expect(subject.conversion).to eq 2.75
  
          @mock.memory[0] = [0xff, 0xf0]
          expect(subject.conversion).to eq(-512.0)
          @mock.memory[0] = [0xff, 0xa0]
          expect(subject.conversion).to eq(-1.5)
        end
      end

      context "FSR +/- 256mV" do
        before do
          subject.configuration({ gain_mode: :quarter_V })
        end

        it "should give correct readings" do
          @mock.memory[0] = [0x7f, 0xf0]
          expect(subject.conversion).to eq 255.875
          @mock.memory[0] = [0x00, 0xb0]
          expect(subject.conversion).to eq 1.375
  
          @mock.memory[0] = [0xff, 0xf0]
          expect(subject.conversion).to eq(-256.0)
          @mock.memory[0] = [0xff, 0xa0]
          expect(subject.conversion).to eq(-0.75)
        end
      end
    end
  end

  describe I2CDevice::ADS101x::ADS1015 do
    before do
      @mock = MockADS101x.new
      allow(File).to receive(:open) do
        @mock.open
      end
  
      @driver = I2CDevice::Driver::I2CDev.new(@mock.path)
    end

    let(:subject) do
      I2CDevice::ADS101x::ADS1015.new(
        address: I2CDevice::ADS101x::ADDRESS[:addr_pin_ground],
        driver:  @driver
      )
    end

    context "config" do
      it "should read default config" do
        expect(subject.configuration.operational_status).to eq :not_converting
        expect(subject.configuration.input_multiplexer).to eq :ain0_ain1
        expect(subject.configuration.gain_mode).to eq :two_V
        expect(subject.configuration.operation_mode).to eq :one_shot
        expect(subject.configuration.data_rate).to eq :sps1600
        expect(subject.configuration.comparator_mode).to eq :traditional
        expect(subject.configuration.comparator_polarity).to eq :active_low
        expect(subject.configuration.comparator_latch).to eq :non_latching
        expect(subject.configuration.comparator_queue).to eq :disable
      end

      it "should write config" do
        subject.configuration(
          {
            operational_status:  :noop,
            input_multiplexer:   :ain0_ain3,
            gain_mode:           :four_V,
            operation_mode:      :continuous,
            data_rate:           :sps490,
            comparator_mode:     :window,
            comparator_polarity: :active_high,
            comparator_latch:    :latching,
            comparator_queue:    :one_conversion
          }
        )
        expect(subject.configuration.operational_status).to eq :converting
        expect(subject.configuration.input_multiplexer).to eq :ain0_ain3
        expect(subject.configuration.gain_mode).to eq :four_V
        expect(subject.configuration.operation_mode).to eq :continuous
        expect(subject.configuration.data_rate).to eq :sps490
        expect(subject.configuration.comparator_mode).to eq :window
        expect(subject.configuration.comparator_polarity).to eq :active_high
        expect(subject.configuration.comparator_latch).to eq :latching
        expect(subject.configuration.comparator_queue).to eq :one_conversion
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
