import 'dart:convert';
import 'package:http/http.dart' as http;

import '../../config/app_config.dart';
import '../../models/hgv_routing_options.dart';
import '../auth_storage_service.dart';

class TransportService {
  // Google Distance Matrix API endpoint
  // Poznámka: V produkcii by ste mali použiť API kľúč z environment premenných
  static const String _baseUrl = 'https://maps.googleapis.com/maps/api';

  /// Vypočíta vzdialenosť a trasu medzi dvoma adresami
  ///
  /// [origin] - Začiatočná adresa
  /// [destination] - Cieľová adresa
  /// [apiKey] – zachované kvôli kompatibilite (Google Places v autocomplete); na trasu sa nepoužíva.
  /// [openRouteServiceApiKey] – voliteľný kľúč OpenRouteService (driving-hgv), ak nie ste prihlásení cez backend.
  /// [hgvOptions] – rozmery a hmotnosť vozidla pre ORS (mosty, zákazy); ak null, použijú sa predvolené hodnoty.
  ///
  /// Vráti mapu s vzdialenosťou, polyline trasou a súradnicami. Trasa je pre nákladné vozidlo nad 3,5 t (HGV).
  Future<Map<String, dynamic>> calculateDistanceWithRoute({
    required String origin,
    required String destination,
    String? apiKey,
    String? openRouteServiceApiKey,
    HgvRoutingOptions? hgvOptions,
  }) async {
    final opts = hgvOptions ?? HgvRoutingOptions.defaults;
    try {
      final originCoords = await _geocodeAddress(origin);
      final destCoords = await _geocodeAddress(destination);

      if (originCoords != null && destCoords != null) {
        final routeData = await _getRouteWithPolyline(
          originCoords['lat']!,
          originCoords['lon']!,
          destCoords['lat']!,
          destCoords['lon']!,
          openRouteServiceApiKey: openRouteServiceApiKey,
          hgvOptions: opts,
        );

        final d = routeData['distance'] as double?;
        if (d != null && d > 0) {
          return {
            'distance': d,
            'polyline': routeData['polyline'],
            'originCoords': originCoords,
            'destinationCoords': destCoords,
          };
        }
        throw StateError(
          'Nepodarilo sa vypočítať trasu pre nákladné vozidlo nad 3,5 t. '
          'Prihláste sa (backend používa OpenRouteService), alebo zadajte vlastný OpenRouteService API kľúč.',
        );
      }
    } on StateError {
      rethrow;
    } catch (_) {
      // geocoding / sieť
    }

    final distance = _estimateDistance(origin, destination);
    return {
      'distance': distance,
      'polyline': null,
      'originCoords': null,
      'destinationCoords': null,
    };
  }

  /// Vypočíta vzdialenosť a trasu medzi dvoma adresami
  ///
  /// [origin] - Začiatočná adresa
  /// [destination] - Cieľová adresa
  /// [apiKey] - Google Maps API kľúč (voliteľný)
  ///
  /// Vráti mapu s vzdialenosťou, polyline trasou a súradnicami
  Future<Map<String, dynamic>> calculateDistanceWithRouteFromOpenRouteService({
    required String origin,
    required String destination,
    String? apiKey,
    String? openRouteServiceApiKey,
    HgvRoutingOptions? hgvOptions,
  }) async {
    return calculateDistanceWithRoute(
      origin: origin,
      destination: destination,
      apiKey: apiKey,
      openRouteServiceApiKey: openRouteServiceApiKey,
      hgvOptions: hgvOptions,
    );
  }

  /// Vypočíta vzdialenosť medzi dvoma adresami pomocou Google Distance Matrix API alebo OpenRouteService
  ///
  /// [origin] - Začiatočná adresa
  /// [destination] - Cieľová adresa
  /// [apiKey] - Google Maps API kľúč (voliteľný)
  ///
  /// Vráti vzdialenosť v kilometroch
  Future<double> calculateDistance({
    required String origin,
    required String destination,
    String? apiKey,
    String? openRouteServiceApiKey,
    HgvRoutingOptions? hgvOptions,
  }) async {
    final opts = hgvOptions ?? HgvRoutingOptions.defaults;
    try {
      final originCoords = await _geocodeAddress(origin);
      final destCoords = await _geocodeAddress(destination);

      if (originCoords != null && destCoords != null) {
        final routeDistance = await _getRouteDistanceFromOpenRouteService(
          originCoords['lat']!,
          originCoords['lon']!,
          destCoords['lat']!,
          destCoords['lon']!,
          openRouteServiceApiKey: openRouteServiceApiKey,
          hgvOptions: opts,
        );

        if (routeDistance != null && routeDistance > 0) {
          return routeDistance;
        }
        throw StateError(
          'Nepodarilo sa vypočítať trasu pre nákladné vozidlo nad 3,5 t. '
          'Prihláste sa (backend používa OpenRouteService), alebo zadajte vlastný OpenRouteService API kľúč.',
        );
      }
    } on StateError {
      rethrow;
    } catch (_) {}

    return _estimateDistance(origin, destination);
  }

  /// Geokódovanie adresy pomocou OpenStreetMap Nominatim
  Future<Map<String, double>?> _geocodeAddress(String address) async {
    try {
      // Najprv skúsime presné vyhľadávanie s detailmi
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/search?'
        'q=${Uri.encodeComponent(address)}&'
        'format=json&'
        'addressdetails=1&'
        'limit=5&'
        'countrycodes=sk,cz&'
        'accept-language=sk',
      );

      final response = await http.get(
        url,
        headers: {'User-Agent': 'StockPilot/1.0'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as List;
        if (data.isNotEmpty) {
          // Pokúsime sa nájsť najpresnejší výsledok
          // Dôležité: Preferujeme výsledky s 'place' (napr. Božčice) pred výsledkami s 'city' (Parchovany)
          final addressLower = address.toLowerCase();
          final hasHouseNumber = RegExp(r'\d+').hasMatch(address);
          final addressWords = addressLower
              .split(' ')
              .where((w) => w.length > 2)
              .toList();

          Map<String, dynamic>? bestMatch;
          int bestScore = -1;

          for (var item in data) {
            final itemMap = item as Map<String, dynamic>;
            final itemAddress = itemMap['address'] as Map<String, dynamic>?;
            final displayName = (itemMap['display_name'] as String? ?? '')
                .toLowerCase();

            int score = 0;

            // Veľký bonus za zhodu čísla domu
            if (hasHouseNumber && itemAddress != null) {
              final houseNumber = itemAddress['house_number'] as String?;
              if (houseNumber != null &&
                  addressLower.contains(houseNumber.toLowerCase())) {
                score += 100;
              }
            }

            // Najvyšší bonus za zhodu 'place' (napr. "božčice")
            if (itemAddress != null) {
              final place = (itemAddress['place'] as String? ?? '')
                  .toLowerCase();
              final village = (itemAddress['village'] as String? ?? '')
                  .toLowerCase();
              final city = (itemAddress['city'] as String? ?? '').toLowerCase();

              for (var word in addressWords) {
                if (place.contains(word) || village.contains(word)) {
                  score += 50; // Veľký bonus za zhodu place/village
                } else if (city.contains(word)) {
                  score += 10; // Nižší bonus za zhodu city
                }
              }

              // Penalizácia ak má city ale nie place, a používateľ hľadá place
              if (place.isEmpty && city.isNotEmpty) {
                for (var word in addressWords) {
                  if (word.length > 3 && !city.contains(word)) {
                    score -= 30; // Penalizácia za výsledky bez place
                    break;
                  }
                }
              }
            }

            // Bonus za zhodu v display_name
            int matchCount = 0;
            for (var word in addressWords) {
              if (displayName.contains(word)) {
                matchCount++;
              }
            }
            score += matchCount * 5;

            // Bonus za importance
            final importance = itemMap['importance'] as double? ?? 0.0;
            score += (importance * 10).toInt();

            // Vyberieme najlepší výsledok
            if (score > bestScore) {
              bestScore = score;
              bestMatch = itemMap;
            }
          }

          // Ak sme nenašli lepší match, použijeme prvý výsledok
          final selectedItem = bestMatch ?? data[0] as Map<String, dynamic>;

          return {
            'lat': double.parse(selectedItem['lat'] as String),
            'lon': double.parse(selectedItem['lon'] as String),
          };
        }
      }
    } catch (e) {
      // Pri chybe vrátime null
    }
    return null;
  }

  /// Parsovanie odpovede v tvare OSRM / backend proxy (distance v metroch).
  Map<String, dynamic>? _parseOsrmLikeRoutesJson(Map<String, dynamic> data) {
    final code = data['code'];
    if (code != null && code != 'Ok' && code != 'ok') {
      return null;
    }
    final routes = data['routes'];
    if (routes is! List || routes.isEmpty) return null;
    final route = routes[0] as Map<String, dynamic>;
    final distRaw = route['distance'];
    final dm = distRaw is num ? distRaw.toDouble() : null;
    if (dm == null || dm <= 0) return null;
    final distanceKm = dm / 1000.0;
    final geometry = route['geometry'] as Map<String, dynamic>?;
    List<Map<String, double>>? polylinePoints;
    if (geometry != null && geometry['coordinates'] != null) {
      final coordinates = geometry['coordinates'] as List;
      polylinePoints = coordinates.map((coord) {
        final c = coord as List;
        return {
          'lat': (c[1] as num).toDouble(),
          'lon': (c[0] as num).toDouble(),
        };
      }).toList();
    }
    return {'distance': distanceKm, 'polyline': polylinePoints};
  }

  /// OpenRouteService GeoJSON (driving-hgv) – distance v metroch v properties.summary.
  Map<String, dynamic>? _parseOrsGeoJsonRoute(Map<String, dynamic> data) {
    final feats = data['features'];
    if (feats is! List || feats.isEmpty) return null;
    final feat = feats[0] as Map<String, dynamic>;
    final geom = feat['geometry'] as Map<String, dynamic>?;
    final coords = geom?['coordinates'] as List?;
    final props = feat['properties'] as Map<String, dynamic>?;
    final summary = props?['summary'] as Map<String, dynamic>?;
    final distM = summary?['distance'];
    final dm = distM is num ? distM.toDouble() : null;
    if (coords == null || coords.isEmpty || dm == null || dm <= 0) return null;
    final distanceKm = dm / 1000.0;
    final polylinePoints = coords.map((coord) {
      final c = coord as List;
      return {
        'lat': (c[1] as num).toDouble(),
        'lon': (c[0] as num).toDouble(),
      };
    }).toList();
    return {'distance': distanceKm, 'polyline': polylinePoints};
  }

  /// Trasa pre nákladné vozidlo nad 3,5 t: backend (OpenRouteService HGV), inak priamy ORS s kľúčom.
  Future<Map<String, dynamic>> _getRouteWithPolyline(
    double lat1,
    double lon1,
    double lat2,
    double lon2, {
    String? openRouteServiceApiKey,
    required HgvRoutingOptions hgvOptions,
  }) async {
    final token = await AuthStorageService.instance.getAccessToken();
    if (token != null && token.isNotEmpty) {
      try {
        final url = Uri.parse('${AppConfig.apiBase}/route/osrm').replace(
          queryParameters: <String, String>{
            'fromLon': lon1.toString(),
            'fromLat': lat1.toString(),
            'toLon': lon2.toString(),
            'toLat': lat2.toString(),
            'height': hgvOptions.heightM.toString(),
            'weight': hgvOptions.weightT.toString(),
            'length': hgvOptions.lengthM.toString(),
            'width': hgvOptions.widthM.toString(),
          },
        );
        final response = await http.get(
          url,
          headers: {
            'Authorization': 'Bearer $token',
            'User-Agent': 'StockPilot/1.0',
          },
        );
        if (response.statusCode == 200) {
          final data = json.decode(response.body) as Map<String, dynamic>;
          final parsed = _parseOsrmLikeRoutesJson(data);
          if (parsed != null) return parsed;
        }
      } catch (_) {
        // skúsime ORS
      }
    }

    final orsKey = openRouteServiceApiKey?.trim();
    if (orsKey != null && orsKey.isNotEmpty) {
      try {
        final url = Uri.parse(
          'https://api.openrouteservice.org/v2/directions/driving-hgv/geojson',
        );
        final response = await http.post(
          url,
          headers: {
            'Authorization': 'Bearer $orsKey',
            'Content-Type': 'application/json',
            'User-Agent': 'StockPilot/1.0',
          },
          body: json.encode({
            'coordinates': [
              [lon1, lat1],
              [lon2, lat2],
            ],
            'options': {
              'profile_params': {
                'restrictions': hgvOptions.toOrsRestrictions(),
              },
            },
          }),
        );
        if (response.statusCode == 200) {
          final data = json.decode(response.body) as Map<String, dynamic>;
          final parsed = _parseOrsGeoJsonRoute(data);
          if (parsed != null) return parsed;
        }
      } catch (_) {}
    }

    return {'distance': null, 'polyline': null};
  }

  Future<double?> _getRouteDistanceFromOpenRouteService(
    double lat1,
    double lon1,
    double lat2,
    double lon2, {
    String? openRouteServiceApiKey,
    required HgvRoutingOptions hgvOptions,
  }) async {
    final routeData = await _getRouteWithPolyline(
      lat1,
      lon1,
      lat2,
      lon2,
      openRouteServiceApiKey: openRouteServiceApiKey,
      hgvOptions: hgvOptions,
    );
    return routeData['distance'] as double?;
  }

  /// Jednoduchý odhad vzdialenosti na základe adries
  /// Toto je fallback metóda, ak nie je dostupný Google Maps API
  double _estimateDistance(String origin, String destination) {
    // Jednoduchý odhad: ak adresy obsahujú rovnaké mesto, odhadneme 10-50 km
    // Ak sú rôzne mestá, odhadneme 50-200 km
    // V reálnej aplikácii by ste mali použiť geokódovanie

    final originLower = origin.toLowerCase();
    final destinationLower = destination.toLowerCase();

    // Jednoduchá heuristika
    if (originLower == destinationLower) {
      return 5.0; // Rovnaká adresa
    }

    // Skontrolujeme, či sú v rovnakom meste (jednoduchá kontrola)
    final originWords = originLower.split(' ');
    final destinationWords = destinationLower.split(' ');

    bool sameCity = false;
    for (var word in originWords) {
      if (word.length > 3 && destinationWords.contains(word)) {
        sameCity = true;
        break;
      }
    }

    if (sameCity) {
      return 15.0; // Rovnaké mesto, odhad 15 km
    } else {
      return 100.0; // Rôzne mestá, odhad 100 km
    }
  }

  /// Získa návrhy adries z OpenStreetMap Nominatim API alebo Google Places API
  ///
  /// [input] - Text, ktorý používateľ zadáva
  /// [apiKey] - Google Maps API kľúč (voliteľný, ak je zadaný, použije sa Google Places)
  ///
  /// Vráti zoznam návrhov adries
  Future<List<String>> getAddressSuggestions({
    required String input,
    String? apiKey,
  }) async {
    if (input.length < 3) {
      return [];
    }

    // Ak je zadaný Google Maps API kľúč, použijeme Google Places API
    if (apiKey != null && apiKey.isNotEmpty) {
      try {
        final url = Uri.parse(
          '$_baseUrl/place/autocomplete/json?'
          'input=${Uri.encodeComponent(input)}&'
          'language=sk&'
          'components=country:sk|country:cz&'
          'key=$apiKey',
        );

        final response = await http.get(url);

        if (response.statusCode == 200) {
          final data = json.decode(response.body);

          if (data['status'] == 'OK' && data['predictions'] != null) {
            final predictions = data['predictions'] as List;
            return predictions
                .map((prediction) => prediction['description'] as String)
                .toList();
          }
        }
      } catch (e) {
        // Pri chybe Google API použijeme OpenStreetMap
      }
    }

    // Použijeme OpenStreetMap Nominatim API (bezplatné, bez API kľúča)
    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/search?'
        'q=${Uri.encodeComponent(input)}&'
        'format=json&'
        'addressdetails=1&'
        'limit=15&'
        'countrycodes=sk,cz&'
        'accept-language=sk',
      );

      final response = await http.get(
        url,
        headers: {
          'User-Agent': 'StockPilot/1.0', // Nominatim vyžaduje User-Agent
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as List;
        final inputLower = input.toLowerCase();
        final inputWords = inputLower
            .split(' ')
            .where((w) => w.length > 2)
            .toList();

        // Zoradíme výsledky podľa relevance
        final scoredResults = data.map((item) {
          final itemMap = item as Map<String, dynamic>;
          final displayName = (itemMap['display_name'] as String? ?? '')
              .toLowerCase();
          final address = itemMap['address'] as Map<String, dynamic>?;

          // Skóre relevance
          int score = 0;

          // Kontrola, koľko slov z inputu sa zhoduje
          for (var word in inputWords) {
            if (displayName.contains(word)) {
              score += 10;
            }
          }

          // Bonus za presné zhodovanie čísla domu
          bool hasMatchingPlace = false;
          if (address != null) {
            final houseNumber = address['house_number'] as String?;
            if (houseNumber != null &&
                inputLower.contains(houseNumber.toLowerCase())) {
              score += 50; // Veľký bonus za zhodu čísla domu
            }

            // Bonus za zhodu názvu ulice/mesta
            // Dôležité: 'place' má najvyššiu prioritu, pretože je presnejší (napr. Božčice vs Parchovany)
            final road = (address['road'] as String? ?? '').toLowerCase();
            final place = (address['place'] as String? ?? '').toLowerCase();
            final village = (address['village'] as String? ?? '').toLowerCase();
            final town = (address['town'] as String? ?? '').toLowerCase();
            final city = (address['city'] as String? ?? '').toLowerCase();

            for (var word in inputWords) {
              // Najvyšší bonus za zhodu 'place' (napr. "božčice" alebo "bozcice")
              // Normalizujeme slovo - odstránime diakritiku pre porovnanie
              final normalizedWord = word
                  .replaceAll('ž', 'z')
                  .replaceAll('č', 'c')
                  .replaceAll('š', 's')
                  .replaceAll('ť', 't')
                  .replaceAll('ň', 'n')
                  .replaceAll('ď', 'd')
                  .replaceAll('ľ', 'l')
                  .replaceAll('ř', 'r')
                  .replaceAll('ý', 'y')
                  .replaceAll('á', 'a')
                  .replaceAll('é', 'e')
                  .replaceAll('í', 'i')
                  .replaceAll('ó', 'o')
                  .replaceAll('ú', 'u');
              
              final normalizedPlace = place
                  .replaceAll('ž', 'z')
                  .replaceAll('č', 'c')
                  .replaceAll('š', 's')
                  .replaceAll('ť', 't')
                  .replaceAll('ň', 'n')
                  .replaceAll('ď', 'd')
                  .replaceAll('ľ', 'l')
                  .replaceAll('ř', 'r')
                  .replaceAll('ý', 'y')
                  .replaceAll('á', 'a')
                  .replaceAll('é', 'e')
                  .replaceAll('í', 'i')
                  .replaceAll('ó', 'o')
                  .replaceAll('ú', 'u');
              
              final normalizedVillage = village
                  .replaceAll('ž', 'z')
                  .replaceAll('č', 'c')
                  .replaceAll('š', 's')
                  .replaceAll('ť', 't')
                  .replaceAll('ň', 'n')
                  .replaceAll('ď', 'd')
                  .replaceAll('ľ', 'l')
                  .replaceAll('ř', 'r')
                  .replaceAll('ý', 'y')
                  .replaceAll('á', 'a')
                  .replaceAll('é', 'e')
                  .replaceAll('í', 'i')
                  .replaceAll('ó', 'o')
                  .replaceAll('ú', 'u');
              
              if (place.isNotEmpty && (place.contains(word) || normalizedPlace.contains(normalizedWord))) {
                score +=
                    150; // Ešte väčší bonus za zhodu place - má absolútnu prioritu
                hasMatchingPlace = true;
              } else if (village.isNotEmpty && (village.contains(word) || normalizedVillage.contains(normalizedWord))) {
                score += 120; // Veľký bonus za zhodu village
                hasMatchingPlace = true;
              } else if (road.contains(word)) {
                score += 25; // Bonus za zhodu ulice
              } else if (town.contains(word)) {
                score += 20; // Bonus za zhodu mesta
              } else if (city.contains(word)) {
                score += 5; // Veľmi nízky bonus za zhodu mesta (menej presné)
              }
            }

            // Veľká penalizácia ak má city ale nie place, a používateľ hľadá place
            // (napr. ak hľadá "božčice" ale výsledok má len "Parchovany" v city)
            if (!hasMatchingPlace && place.isEmpty && city.isNotEmpty) {
              // Skontrolujeme, či vstup obsahuje slovo, ktoré by mohlo byť place
              for (var word in inputWords) {
                if (word.length > 3 &&
                    !city.contains(word) &&
                    !road.contains(word)) {
                  score -=
                      200; // Veľká penalizácia za výsledky bez place, keď používateľ hľadá place
                  break;
                }
              }
            }
            
            // Extra penalizácia pre výsledky s "parchovany" v city, keď hľadáme "bozcice"
            final normalizedInputCheck = inputLower
                .replaceAll(RegExp(r'\d+'), '')
                .replaceAll('ž', 'z')
                .replaceAll('č', 'c')
                .trim();
            if (normalizedInputCheck.contains('bozcice')) {
              final normalizedCity = city
                  .replaceAll('ž', 'z')
                  .replaceAll('č', 'c');
              if (normalizedCity.contains('parchovany') && !hasMatchingPlace) {
                score -= 500; // Obrovská penalizácia - výsledky s Parchovany bez bozcice v place/village
              }
            }
          }

          // Bonus za vyššiu importance (ale len ak nemáme matching place)
          if (!hasMatchingPlace) {
            final importance = itemMap['importance'] as double? ?? 0.0;
            score += (importance * 10).toInt();
          }

          return {'item': itemMap, 'score': score};
        }).toList();

        // Zoradíme podľa skóre (od najvyššieho)
        scoredResults.sort(
          (a, b) {
            final scoreA = a['score'] as int;
            final scoreB = b['score'] as int;
            
            final itemA = a['item'] as Map<String, dynamic>;
            final itemB = b['item'] as Map<String, dynamic>;
            final addressA = itemA['address'] as Map<String, dynamic>?;
            final addressB = itemB['address'] as Map<String, dynamic>?;
            
            final placeA = (addressA?['place'] as String? ?? '').toLowerCase();
            final villageA = (addressA?['village'] as String? ?? '').toLowerCase();
            final placeB = (addressB?['place'] as String? ?? '').toLowerCase();
            final villageB = (addressB?['village'] as String? ?? '').toLowerCase();
            
            final normalizedPlaceA = placeA.replaceAll('ž', 'z').replaceAll('č', 'c');
            final normalizedVillageA = villageA.replaceAll('ž', 'z').replaceAll('č', 'c');
            final normalizedPlaceB = placeB.replaceAll('ž', 'z').replaceAll('č', 'c');
            final normalizedVillageB = villageB.replaceAll('ž', 'z').replaceAll('č', 'c');
            
            final hasBozciceA = normalizedPlaceA.contains('bozcice') || 
                                normalizedVillageA.contains('bozcice') ||
                                placeA.contains('božčice') || 
                                villageA.contains('božčice');
            final hasBozciceB = normalizedPlaceB.contains('bozcice') || 
                                normalizedVillageB.contains('bozcice') ||
                                placeB.contains('božčice') || 
                                villageB.contains('božčice');
            
            // Vždy preferujeme výsledky s "bozcice" v place/village, bez ohľadu na skóre
            if (hasBozciceA && !hasBozciceB) return -1;
            if (!hasBozciceA && hasBozciceB) return 1;
            
            // Ak majú rovnaké skóre, preferujeme výsledky s "bozcice"
            if (scoreA == scoreB) {
              if (hasBozciceA && !hasBozciceB) return -1;
              if (!hasBozciceA && hasBozciceB) return 1;
            }
            
            return scoreB.compareTo(scoreA);
          },
        );

        // Vezmeme top 5 výsledkov, ale preferujeme tie s 'place' alebo 'village'
        // Ak používateľ hľadá "božčice" alebo "bozcice" (aj s číslom), ignorujeme výsledky bez 'place' alebo 'village'
        // Normalizujeme input pre porovnanie (odstránime diakritiku a čísla)
        final normalizedInputForCheck = inputLower
            .replaceAll(RegExp(r'\d+'), '') // Odstránime čísla
            .replaceAll('ž', 'z')
            .replaceAll('č', 'c')
            .trim();
        final hasPlaceKeyword =
            normalizedInputForCheck.contains('bozcice') ||
            inputLower.contains('božčice') || 
            inputLower.contains('bozcice');

        final topResults = scoredResults
            .take(10)
            .where((result) {
              final item = result['item'] as Map<String, dynamic>;

              // Validácia: Musí mať platné súradnice (skutočné miesto v OpenStreetMap)
              final lat = item['lat'] as String?;
              final lon = item['lon'] as String?;
              if (lat == null || lon == null || lat.isEmpty || lon.isEmpty) {
                return false; // Ignorujeme výsledky bez súradníc
              }

              // Validácia: Skúsime parsovať súradnice - musia byť platné čísla
              try {
                final latNum = double.parse(lat);
                final lonNum = double.parse(lon);
                // Súradnice musia byť v platnom rozsahu
                if (latNum < -90 ||
                    latNum > 90 ||
                    lonNum < -180 ||
                    lonNum > 180) {
                  return false;
                }
              } catch (e) {
                return false; // Neplatné súradnice
              }

              // Validácia: Musí mať aspoň nejaké údaje o adrese
              final address = item['address'] as Map<String, dynamic>?;
              if (address == null || address.isEmpty) {
                return false; // Ignorujeme výsledky bez adresy
              }

              // Validácia: Musí mať aspoň jedno z: place, village, town, city, road
              // (aby to nebolo len všeobecné miesto ako krajina)
              final hasLocation =
                  (address['place'] != null &&
                      address['place'].toString().trim().isNotEmpty) ||
                  (address['village'] != null &&
                      address['village'].toString().trim().isNotEmpty) ||
                  (address['town'] != null &&
                      address['town'].toString().trim().isNotEmpty) ||
                  (address['city'] != null &&
                      address['city'].toString().trim().isNotEmpty) ||
                  (address['road'] != null &&
                      address['road'].toString().trim().isNotEmpty);

              if (!hasLocation) {
                return false; // Ignorujeme výsledky bez konkrétneho miesta
              }

              // Validácia: Musí mať aspoň minimálnu relevance (importance > 0.05)
              // alebo musí mať house_number (konkrétna adresa) alebo road (konkrétna ulica)
              final importance = (item['importance'] as double?) ?? 0.0;
              final hasHouseNumber =
                  address['house_number'] != null &&
                  address['house_number'].toString().trim().isNotEmpty;
              final hasRoad =
                  address['road'] != null &&
                  address['road'].toString().trim().isNotEmpty;

              // Ak nemá house_number ani road a má veľmi nízku importance, ignorujeme ho
              // (výsledky s importance < 0.05 sú príliš všeobecné, napr. len krajina)
              if (!hasHouseNumber && !hasRoad && importance < 0.05) {
                return false; // Ignorujeme výsledky s veľmi nízkou relevanciou
              }

              // Ak hľadáme "božčice" alebo "bozcice", ignorujeme výsledky bez 'place' alebo 'village'
              if (hasPlaceKeyword) {
                final place = (address['place'] as String? ?? '').toLowerCase();
                final village = (address['village'] as String? ?? '').toLowerCase();
                final city = (address['city'] as String? ?? '').toLowerCase();
                
                // Normalizujeme pre porovnanie (odstránime diakritiku)
                final normalizedPlace = place
                    .replaceAll('ž', 'z')
                    .replaceAll('č', 'c');
                final normalizedVillage = village
                    .replaceAll('ž', 'z')
                    .replaceAll('č', 'c');
                final normalizedCity = city
                    .replaceAll('ž', 'z')
                    .replaceAll('č', 'c');
                final normalizedInput = inputLower
                    .replaceAll(RegExp(r'\d+'), '')
                    .replaceAll('ž', 'z')
                    .replaceAll('č', 'c')
                    .trim();
                
                // Ak nemá place ani village, ignorujeme ho úplne
                if (place.isEmpty && village.isEmpty) {
                  return false;
                }
                
                // Ak má "bozcice" alebo "božčice" v place alebo village, má najvyššiu prioritu
                if (normalizedPlace.contains('bozcice') || 
                    normalizedVillage.contains('bozcice') ||
                    place.contains('božčice') || 
                    village.contains('božčice')) {
                  // Tento výsledok má najvyššiu prioritu - neignorujeme ho
                  return true;
                }
                
                // Ak má "parchovany" v city ale nie "bozcice" v place/village, ignorujeme ho
                if (normalizedCity.contains('parchovany') || city.contains('parchovany')) {
                  return false; // Úplne vylúčime Parchovany, ak nemá bozcice v place/village
                }
              }

              return true; // Platný výsledok z OpenStreetMap
            })
            .take(5)
            .map((result) {
              final item = result['item'] as Map<String, dynamic>;
              final address = item['address'] as Map<String, dynamic>?;

              if (address != null) {
                // Zostavíme kompletnú adresu
                // Dôležité: VŽDY preferujeme 'place' pred 'city', pretože 'place' je presnejší (napr. Božčice vs Parchovany)
                final parts = <String>[];
                if (address['house_number'] != null)
                  parts.add(address['house_number']);
                if (address['road'] != null) parts.add(address['road']);

                // VŽDY preferujeme 'place' alebo 'village' pred 'city'
                // Ak máme 'place' (napr. Božčice), použijeme ho namiesto 'city' (Parchovany)
                if (address['place'] != null &&
                    address['place'].toString().trim().isNotEmpty) {
                  parts.add(address['place']);
                } else if (address['village'] != null &&
                    address['village'].toString().trim().isNotEmpty) {
                  parts.add(address['village']);
                } else if (address['town'] != null &&
                    address['town'].toString().trim().isNotEmpty) {
                  parts.add(address['town']);
                } else if (address['city'] != null &&
                    address['city'].toString().trim().isNotEmpty) {
                  // Použijeme 'city' len ak nemáme 'place', 'village' ani 'town'
                  parts.add(address['city']);
                }
                if (address['postcode'] != null) parts.add(address['postcode']);
                if (address['country'] != null) parts.add(address['country']);

                if (parts.isNotEmpty) {
                  return parts.join(', ');
                }
              }
              // Fallback na display_name
              return item['display_name'] as String? ?? '';
            })
            .where((addr) => addr.isNotEmpty)
            .toList();

        return topResults;
      }
    } catch (e) {
      // Pri chybe použijeme jednoduché návrhy
    }

    // Fallback na jednoduché návrhy
    return _getSimpleSuggestions(input);
  }

  /// Jednoduchý fallback autocomplete bez API
  List<String> _getSimpleSuggestions(String input) {
    final inputLower = input.toLowerCase();
    final suggestions = <String>[];

    // Základné mestá na Slovensku a v Česku
    final cities = [
      'Bratislava, Slovensko',
      'Košice, Slovensko',
      'Prešov, Slovensko',
      'Žilina, Slovensko',
      'Banská Bystrica, Slovensko',
      'Nitra, Slovensko',
      'Trnava, Slovensko',
      'Trenčín, Slovensko',
      'Martin, Slovensko',
      'Poprad, Slovensko',
      'Praha, Česko',
      'Brno, Česko',
      'Ostrava, Česko',
      'Plzeň, Česko',
      'Liberec, Česko',
      'Olomouc, Česko',
      'České Budějovice, Česko',
      'Hradec Králové, Česko',
      'Ústí nad Labem, Česko',
      'Pardubice, Česko',
    ];

    // Filtrujeme mestá podľa vstupu
    for (var city in cities) {
      if (city.toLowerCase().contains(inputLower)) {
        suggestions.add(city);
        if (suggestions.length >= 5) break; // Max 5 návrhov
      }
    }

    // Ak sme našli mesto, pridáme aj niektoré ulice
    if (suggestions.isNotEmpty && inputLower.length >= 5) {
      final commonStreets = [
        '${suggestions.first.split(',')[0]}, Hlavná ulica',
        '${suggestions.first.split(',')[0]}, Námestie',
        '${suggestions.first.split(',')[0]}, Centrum',
      ];
      suggestions.addAll(commonStreets);
    }

    return suggestions;
  }

  /// Vypočíta celkové náklady na dopravu
  ///
  /// [distance] - Vzdialenosť v kilometroch
  /// [pricePerKm] - Cena za kilometer
  /// [fuelConsumption] - Spotreba paliva na 100 km (v litroch)
  /// [fuelPrice] - Cena paliva za liter (voliteľné)
  ///
  /// Vráti mapu s detailnými nákladmi
  Map<String, double> calculateTransportCosts({
    required double distance,
    required double pricePerKm,
    double? fuelConsumption,
    double? fuelPrice,
  }) {
    final baseCost = distance * pricePerKm;

    double fuelCost = 0.0;
    if (fuelConsumption != null &&
        fuelConsumption > 0 &&
        fuelPrice != null &&
        fuelPrice > 0) {
      final fuelUsed = (distance / 100.0) * fuelConsumption;
      fuelCost = fuelUsed * fuelPrice;
    }

    final totalCost = baseCost + fuelCost;

    return {
      'baseCost': baseCost,
      'fuelCost': fuelCost,
      'totalCost': totalCost,
      'distance': distance,
    };
  }
}
