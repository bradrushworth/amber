class Usage {
  String? type;
  int? duration;
  String? date;
  String? endTime;
  String? quality;
  num? kwh;
  String? nemTime;
  num? perKwh;
  String? channelType;
  String? channelIdentifier;
  num? cost;
  num? renewables;
  num? spotPerKwh;
  String? startTime;
  String? spikeStatus;
  TariffInformation? tariffInformation;
  String? descriptor;

  Usage(
      {this.type,
      this.duration,
      this.date,
      this.endTime,
      this.quality,
      this.kwh,
      this.nemTime,
      this.perKwh,
      this.channelType,
      this.channelIdentifier,
      this.cost,
      this.renewables,
      this.spotPerKwh,
      this.startTime,
      this.spikeStatus,
      this.tariffInformation,
      this.descriptor});

  Usage.fromJson(Map<String, dynamic> json) {
    type = json['type'];
    duration = json['duration'];
    date = json['date'];
    endTime = json['endTime'];
    quality = json['quality'];
    kwh = json['kwh'];
    nemTime = json['nemTime'];
    perKwh = json['perKwh'];
    channelType = json['channelType'];
    channelIdentifier = json['channelIdentifier'];
    cost = json['cost'];
    renewables = json['renewables'];
    spotPerKwh = json['spotPerKwh'];
    startTime = json['startTime'];
    spikeStatus = json['spikeStatus'];
    tariffInformation = json['tariffInformation'] != null
        ? new TariffInformation.fromJson(json['tariffInformation'])
        : null;
    descriptor = json['descriptor'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {};
    data['type'] = type;
    data['duration'] = duration;
    data['date'] = date;
    data['endTime'] = endTime;
    data['quality'] = quality;
    data['kwh'] = kwh;
    data['nemTime'] = nemTime;
    data['perKwh'] = perKwh;
    data['channelType'] = channelType;
    data['channelIdentifier'] = channelIdentifier;
    data['cost'] = cost;
    data['renewables'] = renewables;
    data['spotPerKwh'] = spotPerKwh;
    data['startTime'] = startTime;
    data['spikeStatus'] = spikeStatus;
    if (tariffInformation != null) {
      data['tariffInformation'] = tariffInformation!.toJson();
    }
    data['descriptor'] = descriptor;
    return data;
  }
}

class TariffInformation {
  String? period;
  String? season;
  num? block;
  bool? demandWindow;

  TariffInformation({this.period, this.season, this.block, this.demandWindow});

  TariffInformation.fromJson(Map<String, dynamic> json) {
    period = json['period'];
    season = json['season'];
    block = json['block'];
    demandWindow = json['demandWindow'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {};
    data['period'] = period;
    data['season'] = season;
    data['block'] = block;
    data['demandWindow'] = demandWindow;
    return data;
  }
}
