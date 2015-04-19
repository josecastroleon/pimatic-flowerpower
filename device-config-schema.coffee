module.exports ={
  title: "pimatic-flowerpower device config schemas"
  FlowerPowerDevice: {
    title: "FlowerPower config options"
    type: "object"
    properties:
      uuid:
        description: "uuid of the flowerpower to connect"
        type: "string"
      interval:
        description: "Interval between requests"
        format: "number"
        default: 60000
  }
}
