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
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['type'] = this.type;
    data['duration'] = this.duration;
    data['date'] = this.date;
    data['endTime'] = this.endTime;
    data['quality'] = this.quality;
    data['kwh'] = this.kwh;
    data['nemTime'] = this.nemTime;
    data['perKwh'] = this.perKwh;
    data['channelType'] = this.channelType;
    data['channelIdentifier'] = this.channelIdentifier;
    data['cost'] = this.cost;
    data['renewables'] = this.renewables;
    data['spotPerKwh'] = this.spotPerKwh;
    data['startTime'] = this.startTime;
    data['spikeStatus'] = this.spikeStatus;
    if (this.tariffInformation != null) {
      data['tariffInformation'] = this.tariffInformation!.toJson();
    }
    data['descriptor'] = this.descriptor;
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
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['period'] = this.period;
    data['season'] = this.season;
    data['block'] = this.block;
    data['demandWindow'] = this.demandWindow;
    return data;
  }
}
