module.exports = (env) ->
  Promise = env.require 'bluebird'
  convict = env.require "convict"
  assert = env.require 'cassert'
  
  FlowerPower = require "flower-power"
  events = require "events"

  class FlowerPowerPlugin extends env.plugins.Plugin
    init: (app, @framework, @config) =>
      deviceConfigDef = require("./device-config-schema")
      @devices = []

      @framework.deviceManager.registerDeviceClass("FlowerPowerDevice", {
        configDef: deviceConfigDef.FlowerPowerDevice,
        createCallback: (config) =>
          @devices.push config.uuid
          new FlowerPowerDevice(config)
      })
      
      @framework.on "after init", =>
        @ble = @framework.pluginManager.getPlugin 'ble'
        if @ble?
          @ble.registerName 'Flower Power'
          (@ble.addOnScan device for device in @devices)
          @ble.on("discover", (peripheral) =>
            @emit "discover-"+peripheral.uuid, peripheral
          )
        else
          env.logger.warn "flowerpower could not find ble. It will not be able to discover devices"

    addOnScan: (uuid) =>
      env.logger.debug "Adding device "+uuid
      @ble.addOnScan uuid

    removeFromScan: (uuid) =>
      env.logger.debug "Removing device "+uuid
      @ble.removeFromScan uuid

  class FlowerPowerDevice extends env.devices.Sensor
    attributes:
      soilTemperature:
        description: "the measured temperature in soil"
        type: "number"
        unit: '°C'
      airTemperature:
        description: "the measured temperature in air"
        type: "number"
        unit: '°C'
      soilMoisture:
        description: "the measured moisture in soil"
        type: "number"
        unit: '%'
      battery:
        description: "the measured battery"
        type: "number"
        unit: '%'
      sunlight:
        description: "the measured sunlight"
        type: "number"
        unit: 'photons/m2'

    soilTemperature: 0.0
    airTemperature: 0.0
    soilMoisture: 0.0
    sunlight: 0.0
    battery: 0

    constructor: (@config) ->
      @id = config.id
      @name = config.name
      @interval = config.interval
      @uuid = config.uuid
      @peripheral = null
      @connected = false
      super()
      plugin.on("discover-#{@uuid}", (peripheral) =>
        env.logger.debug "device #{@name} found"
        if not @connected
          @connected = true
          @connect peripheral
      )

    connect: (peripheral) =>
      @peripheral = peripheral
      flowerPower = new FlowerPower(peripheral)
      flowerPower.on 'disconnect', =>
        env.logger.debug "device #{@name} disconnected"
        plugin.addOnScan @uuid
        @connected = false
      flowerPower.connect =>
        env.logger.debug "device #{@name} connected"
        plugin.removeFromScan peripheral.uuid
        flowerPower.discoverServicesAndCharacteristics =>
          env.logger.debug "launching read on device #{@name}"
          @readData flowerPower
          setInterval( =>
            env.logger.debug "launching read for device #{@name} after #{@interval}"
            @readData flowerPower
          , @interval)

    readData: (flowerPower) =>
      flowerPower.readSoilTemperature (error, temperature) =>
        @emit "soilTemperature", Number(temperature).toFixed(1)
      flowerPower.readAirTemperature (error, temperature) =>
        @emit "airTemperature", Number(temperature).toFixed(1)
      flowerPower.readSoilMoisture (error, moisture) =>
        @emit "soilMoisture", Number(moisture)
      flowerPower.readSunlight (error, sunlight) =>
        @emit "sunlight", Number(sunlight)
      flowerPower.readBatteryLevel (error, batteryLevel) =>
        @emit "battery", Number(batteryLevel)

    getSoilTemperature: -> Promise.resolve @soilTemperature
    getAirTemperature: -> Promise.resolve @airTemperature
    getSoilMoisture: -> Promise.resolve @soilMoisture
    getSunlight: -> Promise.resolve @sunlight
    getBattery: -> Promise.resolve @battery

  plugin = new FlowerPowerPlugin
  return plugin
