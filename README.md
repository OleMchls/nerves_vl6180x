# Nerves_VL6180X

[![](https://cdn-shop.adafruit.com/970x728/3316-15.jpg)](https://www.adafruit.com/product/3316))

## Installation

The package can be installed by adding `nerves_vl6180x` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:nerves_vl6180x, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc). Once published, the docs can be found at [https://hexdocs.pm/nerves_vl6180x](https://hexdocs.pm/nerves_vl6180x).

## Usage

```elixir
# Open the I2C bus
{:ok, ref} = VL6180X.open("i2c-1")
# => {:ok, %VL6180X{bus: #Reference<0.718871911.268566539.177140>, device: 41}}

# Initialize the sensor
VL6180X.init(ref)
# => :ok

# Read distance
distance_in_mm = VL6180X.range(ref)
# => 147

# This is helpful for debugging strange behavior
VL6180X.range_status(ref)
# => {:ok, :no_error}

# The sensor also supports LUX reading, you need to add the GAIN (the support is experimental!)
lux = VL6180X.lux(ref, VL6180X.als_gain_20)
# => {:ok, 0.0}
```

## Acknowledgements

This library is basically a port of the [Adafruit python driver](https://github.com/adafruit/Adafruit_CircuitPython_VL6180X) :heart:
