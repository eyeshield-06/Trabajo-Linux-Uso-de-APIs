export def loc-from-address [address:string] {
  let url = {
    scheme: "https"
    host: "maps.google.com"
    path: "/maps/api/geocode/json"
    params: {
      address: $address
      key: $mapsAPIkey
    }
  } | url join
  return (http get $url | get results.geometry.location)
}

export def maps-api [
  xf:string
  xi:string
  transport:string = "driving"
  --no:string = ""
] {
  let xi_card = loc-from-address $xi
  let xf_card = loc-from-address $xf
  let url = {
    scheme: "https"
    host: "maps.googleapis.com"
    path: "/maps/api/directions/json"
    params: {
      destination: $"($xf_card.0.lat),($xf_card.0.lng)"
      origin: $"($xi_card.0.lat),($xi_card.0.lng)"
      mode: $transport
      key: $mapsAPIkey
      avoid: $no
    }
  } | url join
  let results = http get $url
  return ($results.routes.legs.0.0.duration.text)
}

export def gemini-api [
  prompt:string
  --version:string = "1.5-pro"
  --temp:float = 1.0
  --personality:string = "Eres un bebe que solo balbucea"
] {
  let url = {
    scheme: "https"
    host: "generativelanguage.googleapis.com"
    path: $"/v1beta/models/gemini-($version):generateContent"
    params: {
      key: $GeminiAPIkey
    }
  } | url join
  let query = {
    contents: {
      role: "user",
      parts: {
        text: $prompt
      }
    },
    systemInstruction: {
      parts: {
        text: $personality
      }
    },
    generationConfig: {
      max_output_tokens: 1000,
      temperature: $temp
    }
  }
  let results = http post --content-type application/json $url $query
  return ($results.candidates.content.parts.0)
}

export def weather-code [
  x:int
  kind:string = "weatherCode"
] {
    return (open code.json | get $kind | get ($x | into string))
}

export def tomorrow-api [
  x:string
  by:string = "now"
] {
  let x_coord = loc-from-address $x
  if $by == "now" {
    let url = {
      scheme: "https"
      host: "api.tomorrow.io"
      path: "/v4/weather/realtime"
      params: {
        location: $"($x_coord.0.lat),($x_coord.0.lng)"
        apikey: $TomorrowAPIkey
      }
    } | url join
    let results = http get $url
    print $"Condiciones Meteorologicas Actuales\n($x)\nHora ~ (date now
    | format date "%H:%m")"
    return ($results.data.values
      | select temperature humidity windSpeed weatherCode
      | update weatherCode {|i| weather-code $i.weatherCode})
  } else if $by == "1h" {
    let url = {
      scheme: "https"
      host: "api.tomorrow.io"
      path: "/v4/weather/forecast"
      params: {
        location: $"($x_coord.0.lat),($x_coord.0.lng)"
        apikey: $TomorrowAPIkey
        timesteps: $by
      }
    } | url join
    let data = http get $url
    let results = $data.timelines.hourly | update time {|i| $i.time
      | format date "%Y-%m-%d %H:%M:%S"}
    let today = $results.time.0 | format date "%Y-%m-%d 23:00:00"
    print $"Condiciones Meteorologicas por Hora\n($x)\nDesde ~ ($results.time.0
    | format date "%H:00")\nHasta ~ 23:00"
    return ($results
      | where time <= $today
      | get values
      | select temperature humidity windSpeed weatherCode
      | update weatherCode {|i| weather-code $i.weatherCode})
  } else {
    let url = {
      scheme: "https"
      host: "api.tomorrow.io"
      path: "/v4/weather/forecast"
      params: {
        location: $"($x_coord.0.lat),($x_coord.0.lng)"
        apikey: $TomorrowAPIkey
        timesteps: $by
      }
    } | url join
    let results = http get $url
    print $"Condiciones Meteorologicas por Dia\n($x)\nDesde ~ ($results.timelines.daily.time.0
    | format date "%A/%b")\nHasta ~ (seq date --days 5 | last | format date "%A/%b")"
    return ($results.timelines.daily.values
      | select weatherCodeMax temperatureMin temperatureMax humidityAvg windSpeedAvg
      | update weatherCodeMax {|i| weather-code $i.weatherCodeMax})
  }
}
