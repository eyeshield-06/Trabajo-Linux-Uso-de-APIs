# Trabajo Linux CLI: Uso de APIs

- [Trabajo Linux CLI: Uso de APIs](#trabajo-linux-cli--uso-de-apis)
  * [Google Maps API](#google-maps-api)
    + [Ejemplo](#ejemplo)
      - [Google Maps](#google-maps)
      - [maps-api](#maps-api)
      - [Google Maps](#google-maps-1)
      - [maps-api](#maps-api-1)
  * [Gemini API](#gemini-api)
    + [Ejemplo](#ejemplo-1)
  * [Tommorow API](#tommorow-api)
    + [Issue](#issue)
    + [Ejemplo](#ejemplo-2)
      - [now](#now)
        * [meteored.cl](#meteoredcl)
        * [tomorrow-api](#tomorrow-api)
      - [1h](#1h)
        * [meteored.cl](#meteoredcl-1)
        * [tomorrow-api](#tomorrow-api-1)
      - [1d](#1d)
        * [meteored.cl](#meteoredcl-2)
        * [tomorrow-api](#tomorrow-api-2)

<small><i><a href='http://ecotrust-canada.github.io/markdown-toc/'>Table of contents generated with markdown-toc</a></i></small>

Primero que nada comentar que tanto para el uso de esta API, como la de Tommorow.io, se uso una funcion auxiliar, que fue desarrollada en clases, y que consiste en entregar un string correspondiente a una dirreccion y retornar dicha direccion en coordenadas.
```sh
export def loc-from-address [address:string] {
  let mapsAPIkey = "AIzaSyBEZtnneznOl34ZIfmQwoJpWZ7n3v8pDr0"
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
```

## Google Maps API
Como ya se comento esta funcion recibe dos string con dirrecciones y con la funcion `loc-from-address` pasa esta a coordenadas, las cuales se incluyen en la url.

Los parametros son:
1. xi - xf (no opcionales, posicionales): Direccion inicial y final.
2. transport (opcional, posicional): Medio de transporte, opciones:
    1. driving (default): Auto.
    2. transit: Transporte publico.
    3. walking: Caminando.
    4. bycicling: Bicicleta.
3. no (opcional, flag): Especificar que evitar. Opciones disponibles:
    1. tolls: Peajes.
    2. highways: Autopistas.
    3. ferries
```sh
export def maps-api [
  xf:string
  xi:string
  transport:string = "driving"
  --no:string = ""
] {
  let mapsAPIkey = "AIzaSyBEZtnneznOl34ZIfmQwoJpWZ7n3v8pDr0"
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
```

### Ejemplo

#### Google Maps
![](imgs/withhighways.png)

#### maps-api
```sh
maps-api "Penco, chile" "Chillan, chile"
```
> 1 hour 5 mins

#### Google Maps
![](imgs/nohighways.png)

#### maps-api
```sh
maps-api "Penco, chile" "Chillan, chile" --no "highways"
```
> 2 hours 19 mins

## Gemini API
A diferencia de con las otras dos API, con la de Gemini la consulta es mas compleja y a su vez mas larga, por lo cual no usamos el comando `http get`, si no que el comando `http post` con el cual estructuramos nuestra query en formato json siguiendo las indicaciones presente en la documentacion.

Los parametros que recibe nuestra funcion son:

1. prompt (no opcional, posicional): Consulta a la API.
2. version (opcional, flag): Modelo de la API a utilizar. [Disponibles](https://ai.google.dev/gemini-api/docs/models/gemini#model-variations).
3. temp (opcional, flag): Grado de aleatoriedad de la respuesta. Bajas temperaturas son recomendadas para query que requieres una respuesta mas deterministica, mientras que temperaturas mas altas conducen a resultados mas diversos y/o creativos. Por lo tanto, temp = 0 respuesta deterministica.
4. personality (opcional, flag): Las instrucciones del sistema son un conjunto de instrucciones que el modelo procesa antes de procesar las instrucciones. Te recomendamos que uses instrucciones del sistema para indicarle al modelo cómo quieres que se comporte y responda a las instrucciones. 
```sh
export def gemini-api [
  prompt:string
  --version:string = "1.5-pro"
  --temp:float = 1.0
  --personality:string = "Eres un bebe que solo balbucea"
] {
  let GeminiAPIkey = "AIzaSyAoseUi0eCZ09R98t_mF-zBvakgXtMbYoc"
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
```

### Ejemplo
```sh
gemini-api "Que dia es hoy"
```
> ¡Agu! ¡Da! ¡Hoy!

La respuesta no tiene sentido ya que se configuro a la IA a comportarse como un bebe que no sabe hablar. Ahora si cambiamos el parametro de personalidad,

```sh
gemini-api "Que dia es hoy" --personality "Eres Gandalf, entonces hablas de forma arcaica"
```
> Este día, viajero, está marcado en los anales del tiempo como martes, 28 de noviembre del año 2023 del Señor.  ¿Adónde te llevan tus viajes en este día señalado?

## Tommorow API
De las 3 API con las que se trabajo esta fue la que necesito un mayor procesamiento de informacion, y al igual que con la de Google Maps, tambien se uso una funcion auxiliar.

Esta funcion pasa los codigos correspondientes a la condicion del clima a su representacion string. El archivo `code.json` se puede encontrar en https://docs.tomorrow.io/reference/data-layers-weather-codes .
```sh
export def weather-code [
  x:int
  kind:string = "weatherCode"
] {
    return (open code.json | get $kind | get ($x | into string))
}
```

Los parametros que recibe la funcion son:
1. x (no opcional, posicional): Lugar que se busca conocer su condicion meteorologica en formato string.
2. by (opcional, posicional): De cuando se quieren conocer los datos. Tiene 3 opciones validas:
    1. now: Condiciones meteorologicas actuales.
    2. 1h: Condiciones meteorologicas por hora hasta finalizar el dia (23:00).
    3. 1d: Conciones meteorologicas para los proximos 5 dias. 
```sh
export def tomorrow-api [
  x:string
  by:string = "now"
] {
  let TomorrowAPIkey = "1N0HLnoSNu6iPgMYM2A4YAOrtJb5hZH1"
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
```

### Issue
Un problema que tuvimos con este, es que en las opciones 1h y 1d que los resultados son tablas, no pudimos resolver el como modificar la columna de indices para cambiar estos del `0...n` por default, a las fechas o horas correspondientes a los registros. Para mitigar esto arriba de la tabla se dice a cuando corresponden las observaciones.

### Ejemplo

#### now

##### meteored.cl
![](imgs/weathernow.png)

##### tomorrow-api
```sh
tomorrow-api "concepcion, chile"
```
```
Condiciones Meteorologicas Actuales
concepcion, chile
Hora ~ 17:01
╭─────────────┬──────────────╮
│ temperature │ 23.19        │
│ humidity    │ 57           │
│ windSpeed   │ 3.38         │
│ weatherCode │ Clear, Sunny │
╰─────────────┴──────────────╯
```

#### 1h

##### meteored.cl
![](imgs/weather1h.png)

##### tomorrow-api
```sh
tomorrow-api "concepcion, chile" "1h"
```
```
Condiciones Meteorologicas por Hora
concepcion, chile
Desde ~ 21:00
Hasta ~ 23:00
╭───┬─────────────┬──────────┬───────────┬──────────────╮
│ # │ temperature │ humidity │ windSpeed │ weatherCode  │
├───┼─────────────┼──────────┼───────────┼──────────────┤
│ 0 │       23.19 │       57 │      3.38 │ Clear, Sunny │
│ 1 │       25.13 │       57 │      6.13 │ Clear, Sunny │
│ 2 │       23.56 │       63 │      5.94 │ Clear, Sunny │
╰───┴─────────────┴──────────┴───────────┴──────────────╯
```
Ademas como se aprecia en la tabla, al usar `1h` los pronosticos retornados no son del momento exacto en el que se ejecuta el comando, si no que hay un delay de unas 3 horas.

#### 1d

##### meteored.cl
![](imgs/weather1d.png)

##### tomorrow-api
```sh
tomorrow-api "concepcion, chile" "1d"
```
```
``Condiciones Meteorologicas por Dia
concepcion, chile
Desde ~ domingo/ene
Hasta ~ viernes/ene
╭───┬────────────────┬────────────────┬────────────────┬─────────────┬──────────────╮
│ # │ weatherCodeMax │ temperatureMin │ temperatureMax │ humidityAvg │ windSpeedAvg │
├───┼────────────────┼────────────────┼────────────────┼─────────────┼──────────────┤
│ 0 │ Clear, Sunny   │          13.50 │          25.38 │       70.96 │         3.16 │
│ 1 │ Clear, Sunny   │          13.06 │          24.38 │       47.71 │         3.67 │
│ 2 │ Clear, Sunny   │          10.45 │          21.75 │       60.62 │         1.94 │
│ 3 │ Clear, Sunny   │          10.08 │          22.87 │       76.34 │         2.43 │
│ 4 │ Cloudy         │           8.64 │          20.71 │       68.19 │         2.50 │
│ 5 │ Clear, Sunny   │           7.83 │          21.83 │       66.60 │         2.41 │
╰───┴────────────────┴────────────────┴────────────────┴─────────────┴──────────────╯`
