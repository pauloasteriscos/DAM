import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const packages = <String, String>{
    'pt-PT': 'assets/content/official_pt_pt_phase1.v8.json',
    'en-US': 'assets/content/official_en_us_phase1.v8.json',
    'es-ES': 'assets/content/official_es_es_phase1.v8.json',
    'fr-FR': 'assets/content/official_fr_fr_phase1.v8.json',
    'it-IT': 'assets/content/official_it_it_phase1.v8.json',
    'de-DE': 'assets/content/official_de_de_phase1.v8.json',
  };
  const lexical = <String, String>{
    'pt-PT': 'assets/content/official_pt_pt_phase1.lexical.v1.json',
    'en-US': 'assets/content/official_en_us_phase1.lexical.v1.json',
    'es-ES': 'assets/content/official_es_es_phase1.lexical.v1.json',
    'fr-FR': 'assets/content/official_fr_fr_phase1.lexical.v1.json',
    'it-IT': 'assets/content/official_it_it_phase1.lexical.v1.json',
    'de-DE': 'assets/content/official_de_de_phase1.lexical.v1.json',
  };
  const locales = <String>{
    'pt-PT',
    'en-US',
    'es-ES',
    'fr-FR',
    'it-IT',
    'de-DE',
  };
  const introduced = <String>{
    'water',
    'i-am-hungry',
    'i-am-thirsty',
    'can-i-have-more-please',
    'i-dont-eat-meat',
  };
  const reinforced = <String>{'thank-you', 'please', 'bathroom'};
  const allItems = <String>{...introduced, ...reinforced};

  test('Lição 3 cumpre o contrato oficial nos seis percursos', () {
    for (final e in packages.entries) {
      final p =
          jsonDecode(File(e.value).readAsStringSync()) as Map<String, dynamic>;
      final pathId = p['id']! as String;
      final lang = pathId.split('.')[1];
      final competencyId = 'arrival.$lang.meal-vocabulary';

      final journey = (p['journeys']! as List).first as Map<String, dynamic>;
      final stage = (journey['stages']! as List)
          .cast<Map<String, dynamic>>()
          .singleWhere((x) => x['id'] == 'arrival.stage-03');

      expect(
        (stage['title']! as Map<String, dynamic>).keys.toSet(),
        containsAll(locales),
      );
      final element =
          ((stage['elements']! as List).single) as Map<String, dynamic>;
      expect(element['activityId'], 'arrival.vocabulary-03');
      expect(element['practicePreference'], 'vocabulary');
      final prereq = element['prerequisites']! as Map<String, dynamic>;
      expect(prereq['type'], 'activityCompleted');
      expect(prereq['activityId'], 'arrival.vocabulary-02');

      final comps = (p['competencies']! as List).cast<Map<String, dynamic>>();
      final comp = comps.singleWhere((x) => x['id'] == competencyId);
      expect(
        (comp['title']! as Map<String, dynamic>).keys.toSet(),
        containsAll(locales),
      );
      expect(
        (comp['description']! as Map<String, dynamic>).keys.toSet(),
        containsAll(locales),
      );

      final activities = (p['activities']! as List)
          .cast<Map<String, dynamic>>();
      expect(activities, hasLength(7));
      final a = activities.singleWhere(
        (x) => x['id'] == 'arrival.vocabulary-03',
      );
      expect(a['currentRevisionId'], 'arrival.vocabulary-03.revision-02');

      final revisions = (a['revisions']! as List).cast<Map<String, dynamic>>();
      expect(revisions, hasLength(2));

      final historicalRevision = revisions.singleWhere(
        (revision) => revision['id'] == 'arrival.vocabulary-03.revision-01',
      );
      final r = revisions.singleWhere(
        (revision) => revision['id'] == 'arrival.vocabulary-03.revision-02',
      );

      expect(historicalRevision['revisionNumber'], 1);
      expect(r['revisionNumber'], 2);
      expect(r['activityId'], 'arrival.vocabulary-03');
      expect((r['competencies']! as List).cast<String>(), <String>[
        competencyId,
      ]);
      final execution = r['execution']! as Map<String, dynamic>;
      expect(execution['kind'], 'vocabulary');
      final items = (execution['items']! as List).cast<Map<String, dynamic>>();
      expect(items, hasLength(8));
      expect(items.map((x) => x['id']! as String).toSet(), allItems);
      for (final item in items) {
        expect(
          (item['text']! as Map<String, dynamic>).keys.toSet(),
          containsAll(locales),
        );
      }

      final l =
          jsonDecode(File(lexical[e.key]!).readAsStringSync())
              as Map<String, dynamic>;
      final la = (l['activities']! as List)
          .cast<Map<String, dynamic>>()
          .singleWhere((x) => x['activityId'] == 'arrival.vocabulary-03');
      expect((la['introduces']! as List).cast<String>().toSet(), introduced);
      expect((la['practises']! as List).cast<String>().toSet(), allItems);
      expect((la['reinforces']! as List).cast<String>().toSet(), reinforced);
    }
  });
}
