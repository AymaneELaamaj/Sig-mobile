class Construction {
  final int? id;
  final String adresse;
  final String contact;
  final String type; // Ex: Résidentiel, Commercial [cite: 14]
  final String geom; // On va stocker les points du polygone sous forme de texte (JSON)

  Construction({
    this.id,
    required this.adresse,
    required this.contact,
    required this.type,
    required this.geom,
  });

  // Convertir un objet Construction en Map pour SQLite
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'adresse': adresse,
      'contact': contact,
      'type': type,
      'geom': geom,
    };
  }

  // Convertir une Map (venant de SQLite) en objet Construction
  factory Construction.fromMap(Map<String, dynamic> map) {
    return Construction(
      id: map['id'],
      adresse: map['adresse'],
      contact: map['contact'],
      type: map['type'],
      geom: map['geom'],
    );
  }
}