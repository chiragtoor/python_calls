defmodule PythonCalls do
  # file containing the example blocks
  @block_file "data/sm_blocks.geojson"
  # file containing the example zones
  @zone_file "data/sm_zones.geojson"
  # files output to depending on the method run
  @thrift_file "data/thrift.geojson"
  @erlport_file "data/erlport.geojson"

  def erlport do
    # Start a python instance to take the function calls
    {:ok, python} = :python.start([{:python_path, to_char_list(Path.expand("python"))}, {:python, 'python'}])
    # Pull out the coordinates of the zones
    commercial_zones = get_commercial_zones()
    |> Enum.map(fn(%{"geometry" => %{"coordinates" => [coordinates]}}) ->
      coordinates
    end)

    commercial_blocks = get_blocks()
    |> Enum.map(fn(geo_json = %{"geometry" => %{"coordinates" => [coordinates]}}) ->
      # Pull out the coordinates, keep the original geo_json because if this
      #  is a commercial block we need to write the original geo_json to the output file
      {geo_json, coordinates}
    end)
    |> Enum.map(fn({geo_json, block}) ->

      function = fn(block, zone) ->
        :python.call(python, :simple, :blockInZone, [block, zone])
      end

      if check_intersection(function, false, block, commercial_zones) do
        geo_json
      else
        nil
      end
    end)

    write_to_file(@erlport_file, commercial_blocks)
  end

  def thrift do
    # Start the client to connect with the thrift service
    PythonCalls.Client.start_link
    # Convert the zones to Boundary structs defined in the geoservice.thrift file
    commercial_zones = get_commercial_zones()
    |> Enum.map(fn(%{"geometry" => %{"coordinates" => [coordinates]}}) ->
      PythonCalls.Models.Boundary.new(points: getPointsFromCoordinates(coordinates))
    end)

    commercial_blocks = get_blocks()
    |> Enum.map(fn(geo_json = %{"geometry" => %{"coordinates" => [coordinates]}}) ->
      # Convert the blocks to Boundary structs, keep the original geo_json because if this
      #  is a commercial block we need to write the original geo_json to the output file
      {geo_json, 
        PythonCalls.Models.Boundary.new(points: getPointsFromCoordinates(coordinates))}
    end)
    |> Enum.map(fn({geo_json, block}) ->

      function = fn(block, zone) ->
        PythonCalls.Client.blockInZone(block, zone)
      end

      if check_intersection(function, false, block, commercial_zones) do
        geo_json
      else
        nil
      end
    end)

    write_to_file(@thrift_file, commercial_blocks)
  end

  # Helper function to convert coordinates to a Point struct for thrift calls
  defp getPointsFromCoordinates(coordinates) do
    coordinates
    |> Enum.map(fn([lng, lat]) ->
      PythonCalls.Models.Point.new(lat: lat, lng: lng)
    end)
  end

  # Helper function to take a block and go through all commercial zones
  #  to check for a intersection
  # Using recursion and pattern matching if at any point we detect a intersection
  #  this will return true
  # Otherwise if no zones intersect with the block this will return false
  defp check_intersection(function, false, block, [zone | zones]) do
    check_intersection(function, function.(block, zone), block, zones)
  end

  defp check_intersection(function, true, _,  _) do
    true
  end

  defp check_intersection(function, false, _, []) do
    false
  end

  # Helper function to write the commercial blocks to a file
  defp write_to_file(file_name, geo_json) do
    data = geo_json
    |> Enum.filter(fn(geo_json) ->
      geo_json != nil
    end)
    |> Enum.map(fn(geo_json) ->
      Poison.encode!(geo_json)
    end)
    |> Enum.join(",\n")

    {:ok, file} = File.open(file_name, [:write])

    IO.write file, "{\"type\": \"FeatureCollection\", \"crs\": { \"type\": \"name\", \"properties\": { \"name\": \"urn:ogc:def:crs:OGC:1.3:CRS84\" } }, \"features\": ["
    IO.write file, data
    IO.write file, "]}"

    File.close file
  end

  # Helper functions to get the zones and blocks out of the files
  # Since the files are very small we can just read them into memory
  #  and decode with Poison to pull out the geojson data needed
  defp get_commercial_zones do
    %{"features" => zones} = Poison.decode!(File.read!(@zone_file))

    zones
  end

  defp get_blocks do
    %{"features" => blocks} = Poison.decode!(File.read!(@block_file))

    blocks
  end
end
