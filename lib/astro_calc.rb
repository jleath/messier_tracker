require 'date'

module AstroCalc
  DEFAULT_EPOCH = Time.utc(2000, 1, 1, 12, 0, 0)

  def hms2decimal(degrees, minutes, seconds)
    sign = degrees < 0.0 ? -1 : 1
    sign * (degrees.abs + (minutes.abs / 60.0) + (seconds.abs / 3600.0))
  end

  def local_siderial_time(dt, longitude, epoch = DEFAULT_EPOCH)
    days = (dt - epoch).to_f / (60.0 * 60.0 * 24.0)
    hours = hms2decimal(dt.hour, dt.min, dt.sec)
    (100.46 + 0.985647 * days + longitude + 15 * hours) % 360
  end

  def asin(degrees)
    Math.asin(degrees) * 180 / Math::PI
  end

  def sin(degrees)
    Math.sin(degrees * Math::PI / 180.0)
  end

  def cos(degrees)
    Math.cos(degrees * Math::PI / 180.0)
  end

  def acos(degrees)
    Math.acos(degrees) * 180 / Math::PI
  end

  def calculate_alt_az(ra, dc, dt, latitude, longitude)
    hour_angle = (local_siderial_time(dt, longitude) - ra) % 360
    alt = asin(sin(dc) * sin(latitude) + cos(dc) * cos(latitude) * cos(hour_angle))
    a = acos((sin(dc) - sin(alt) * sin(latitude)) / (cos(alt) * cos(latitude)))
    az = sin(hour_angle) < 0.0 ? a : 360 - a
    [alt, az]
  end
end