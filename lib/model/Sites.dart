class Site {
  String? id;
  String? nmi;
  List<Channels>? channels;
  String? network;
  String? status;
  String? activeFrom;

  Site(
      {this.id,
        this.nmi,
        this.channels,
        this.network,
        this.status,
        this.activeFrom});

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
    activeFrom = json['activeFrom'];
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
    data['activeFrom'] = this.activeFrom;
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
