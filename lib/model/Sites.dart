import 'package:intl/intl.dart';

class Site {
  String? id;
  String? nmi;
  List<Channels>? channels;
  String? network;
  String? status;
  DateTime? activeFrom;
  DateTime? closedOn;
  int? intervalLength;

  DateFormat dateFormat = DateFormat("yyyy-MM-dd");

  Site(
      {this.id,
        this.nmi,
        this.channels,
        this.network,
        this.status,
        this.activeFrom,
        this.closedOn,
        this.intervalLength});

  Site.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    nmi = json['nmi'];
    if (json['channels'] != null) {
      channels = <Channels>[];
      json['channels'].forEach((v) {
        channels!.add(new Channels.fromJson(v));
      });
    }
    network = json['network'];
    status = json['status'];
    activeFrom = json['activeFrom'] != null ? dateFormat.tryParse(json['activeFrom']) : null;
    closedOn = json['closedOn'] != null ? dateFormat.tryParse(json['closedOn']) : null;
    intervalLength = json['intervalLength'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['id'] = this.id;
    data['nmi'] = this.nmi;
    if (this.channels != null) {
      data['channels'] = this.channels!.map((v) => v.toJson()).toList();
    }
    data['network'] = this.network;
    data['status'] = this.status;
    data['activeFrom'] = dateFormat.format(this.activeFrom!);
    data['closedOn'] = dateFormat.format(this.closedOn!);
    data['intervalLength'] = this.intervalLength;
    return data;
  }
}

class Channels {
  String? identifier;
  String? type;
  String? tariff;

  Channels({this.identifier, this.type, this.tariff});

  Channels.fromJson(Map<String, dynamic> json) {
    identifier = json['identifier'];
    type = json['type'];
    tariff = json['tariff'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['identifier'] = this.identifier;
    data['type'] = this.type;
    data['tariff'] = this.tariff;
    return data;
  }
}
