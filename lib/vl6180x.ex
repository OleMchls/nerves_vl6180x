defmodule VL6180X do
  use Bitwise

  alias Circuits.I2C

  @vl6180x_default_i2c_addr 0x29
  @vl6180x_device_model_identification_number 0xB4
  @vl6180x_reg_identification_model_id 0x000
  @vl6180x_reg_system_interrupt_config 0x014
  @vl6180x_reg_system_interrupt_clear 0x015
  @vl6180x_reg_system_fresh_out_of_reset 0x016
  @vl6180x_reg_sysrange_start 0x018
  @vl6180x_reg_sysals_start 0x038
  @vl6180x_reg_sysals_analogue_gain 0x03F
  @vl6180x_reg_sysals_integration_period_hi 0x040
  @vl6180x_reg_sysals_integration_period_lo 0x041
  @vl6180x_reg_result_als_val 0x050
  @vl6180x_reg_result_range_val 0x062
  @vl6180x_reg_result_range_status 0x04D
  @vl6180x_reg_result_interrupt_status_gpio 0x04F

  @range_states %{
    0b0000 => :no_error,
    0b0001 => :vcsel_continuity_test,
    0b0010 => :vcsel_watchdog_test,
    0b0011 => :vcsel_watchdog,
    0b0100 => :pll1_lock,
    0b0101 => :pll2_lock,
    0b0110 => :early_convergence_estimate,
    0b0111 => :max_convergence,
    0b1000 => :no_target_ignore,
    0b1001 => :not_used,
    0b1010 => :not_used,
    0b1011 => :max_signal_to_noise_ratio,
    0b1100 => :raw_ranging_algo_underflow,
    0b1101 => :raw_ranging_algo_overflow,
    0b1110 => :ranging_algo_underflow,
    0b1111 => :ranging_algo_overflow
  }

  @als_gain_1 0x06
  @als_gain_1_25 0x05
  @als_gain_1_67 0x04
  @als_gain_2_5 0x03
  @als_gain_5 0x02
  @als_gain_10 0x01
  @als_gain_20 0x00
  @als_gain_40 0x07

  defstruct [:bus, :device]

  def open(bus_name, address \\ @vl6180x_default_i2c_addr) do
    {:ok, ref} = I2C.open(bus_name)
    {:ok, << @vl6180x_device_model_identification_number >>} = read8(ref, address, @vl6180x_reg_identification_model_id)
    {:ok, %__MODULE__{bus: ref, device: address}}
  end

  def init(%__MODULE__{bus: bus, device: device}) do
    # private settings from page 24 of app note
    write8(bus, device, 0x0207, 0x01)
    write8(bus, device, 0x0208, 0x01)
    write8(bus, device, 0x0096, 0x00)
    write8(bus, device, 0x0097, 0xFD)
    write8(bus, device, 0x00E3, 0x00)
    write8(bus, device, 0x00E4, 0x04)
    write8(bus, device, 0x00E5, 0x02)
    write8(bus, device, 0x00E6, 0x01)
    write8(bus, device, 0x00E7, 0x03)
    write8(bus, device, 0x00F5, 0x02)
    write8(bus, device, 0x00D9, 0x05)
    write8(bus, device, 0x00DB, 0xCE)
    write8(bus, device, 0x00DC, 0x03)
    write8(bus, device, 0x00DD, 0xF8)
    write8(bus, device, 0x009F, 0x00)
    write8(bus, device, 0x00A3, 0x3C)
    write8(bus, device, 0x00B7, 0x00)
    write8(bus, device, 0x00BB, 0x3C)
    write8(bus, device, 0x00B2, 0x09)
    write8(bus, device, 0x00CA, 0x09)
    write8(bus, device, 0x0198, 0x01)
    write8(bus, device, 0x01B0, 0x17)
    write8(bus, device, 0x01AD, 0x00)
    write8(bus, device, 0x00FF, 0x05)
    write8(bus, device, 0x0100, 0x05)
    write8(bus, device, 0x0199, 0x05)
    write8(bus, device, 0x01A6, 0x1B)
    write8(bus, device, 0x01AC, 0x3E)
    write8(bus, device, 0x01A7, 0x1F)
    write8(bus, device, 0x0030, 0x00)

    # Recommended : Public registers - See data sheet for more detail
    write8(bus, device, 0x0011, 0x10)  # Enables polling for 'New Sample ready' when measurement completes
    write8(bus, device, 0x010A, 0x30)  # Set the averaging sample period  (compromise between lower noise and increased execution time)
    write8(bus, device, 0x003F, 0x46)  # Sets the light and dark gain (upper nibble). Dark gain should not be changed.
    write8(bus, device, 0x0031, 0xFF)  # sets the # of range measurements after which auto calibration of system is performed
    write8(bus, device, 0x0040, 0x63)  # Set ALS integration time to 100ms
    write8(bus, device, 0x002E, 0x01)  # perform a single temperature calibration of the ranging sensor

    # Optional: Public registers - See data sheet for more detail
    write8(bus, device, 0x001B, 0x09)  # Set default ranging inter-measurement period to 100ms
    write8(bus, device, 0x003E, 0x31)  # Set default ALS inter-measurement period to 500ms
    write8(bus, device, 0x0014, 0x24)  # Configures interrupt on 'New Sample Ready threshold event'

    write8(bus, device, @vl6180x_reg_system_fresh_out_of_reset, 0x00)
  end

  def range(%__MODULE__{} = ref) do
    # wait for device to be ready for range measurement
    read8_until(ref.bus, ref.device, @vl6180x_reg_result_range_status, fn
      << _::7, 0x1::1 >> -> true
      _ -> false
    end)
    # Start a range measurement
    write8(ref.bus, ref.device, @vl6180x_reg_sysrange_start, 0x01)
    # Poll until bit 2 is set
    read8_until(ref.bus, ref.device, @vl6180x_reg_result_interrupt_status_gpio, fn
      << _::2, _::3, 0x4::3 >> -> true
      _ -> false
    end)
    # read range in mm
    {:ok, << range >>} = read8(ref.bus, ref.device, @vl6180x_reg_result_range_val)
    # clear interrupt
    write8(ref.bus, ref.device, @vl6180x_reg_system_interrupt_clear, 0x07)

    range
  end

  def range_status(%__MODULE__{} = ref) do
    read8(ref.bus, ref.device, @vl6180x_reg_result_range_status)
    |> determine_range_status
  end

  defp determine_range_status({:ok, << 0::4, _::4 >>}), do: {:ok, :no_error}
  defp determine_range_status({:ok, << code::4, _::4 >>}), do: {:ok, @range_states[code]}
  defp determine_range_status(return), do: return

  def als_gain_1(), do: @als_gain_1
  def als_gain_1_25(), do: @als_gain_1_25
  def als_gain_1_67(), do: @als_gain_1_67
  def als_gain_2_5(), do: @als_gain_2_5
  def als_gain_5(), do: @als_gain_5
  def als_gain_10(), do: @als_gain_10
  def als_gain_20(), do: @als_gain_20
  def als_gain_40(), do: @als_gain_40
  def lux(%__MODULE__{}, gain) when gain > @als_gain_40, do: {:error, :gain_too_high}
  def lux(%__MODULE__{}, gain) when gain < 0x00, do: {:error, :gain_must_be_positive}
  def lux(%__MODULE__{} = ref, gain) do
    # IRQ on ALS ready
    {:ok, << reserved::2, _als_int_mode::3, range_int_mode::3 >>} = read8(ref.bus, ref.device, @vl6180x_reg_system_interrupt_config)
    << reg >> = << reserved::2, 0x4::3, range_int_mode::3 >>
    write8(ref.bus, ref.device, @vl6180x_reg_system_interrupt_config, reg)
    # 100 ms integration period
    write8(ref.bus, ref.device, @vl6180x_reg_sysals_integration_period_hi, 100)
    # write8(ref.bus, ref.device, @vl6180x_reg_sysals_integration_period_hi, 0)
    # write8(ref.bus, ref.device, @vl6180x_reg_sysals_integration_period_lo, 100)
    # analog gain
    write8(ref.bus, ref.device, @vl6180x_reg_sysals_analogue_gain, 0x40 ||| gain)
    # start ALS
    write8(ref.bus, ref.device, @vl6180x_reg_sysals_start, 0x1)
    # Poll until "New Sample Ready threshold event" is set
    read8_until(ref.bus, ref.device, @vl6180x_reg_result_interrupt_status_gpio, fn
      << _::2, 0x4::3, _::3 >> -> true
      _ -> false
    end)
    # read lux!
    {:ok, << lux::16 >>} = read16(ref.bus, ref.device, @vl6180x_reg_result_als_val)
    # clear interrupt
    write8(ref.bus, ref.device, @vl6180x_reg_system_interrupt_clear, 0x07)
    lux = lux * 0.32  # calibrated count/lux
    lux = case gain do
      @als_gain_1 -> lux / 1
      @als_gain_1_25 -> lux / 1.25
      @als_gain_1_67 -> lux / 1.67
      @als_gain_2_5 -> lux / 2.5
      @als_gain_5 -> lux / 5
      @als_gain_10 -> lux / 10
      @als_gain_20 -> lux / 20
      @als_gain_40 -> lux / 40
    end

    {:ok, lux}
  end

  defp write8(bus, device, address, data) do
    I2C.write(bus, device, << (address >>> 8) &&& 0xFF, address &&& 0xFF, data >>)
  end

  defp read8(bus, device, address) do
    I2C.write_read(bus, device, << (address >>> 8) &&& 0xFF, address &&& 0xFF >>, 1)
  end

  defp read8_until(bus, device, address, until) do
    {:ok, result} = read8(bus, device, address)

    if until.(result), do: result, else: read8_until(bus, device, address, until)
  end

  defp read16(bus, device, address) do
    I2C.write_read(bus, device, << (address >>> 8) &&& 0xFF, address &&& 0xFF >>, 2)
  end

end
