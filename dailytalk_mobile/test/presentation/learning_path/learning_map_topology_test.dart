import 'package:dailytalk_mobile/data/repositories/learning_progress_read_repository.dart';
import 'package:dailytalk_mobile/domain/learning/domain_ids.dart';
import 'package:dailytalk_mobile/domain/learning/learning_enums.dart';
import 'package:dailytalk_mobile/domain/learning/learning_models.dart';
import 'package:dailytalk_mobile/domain/learning/prerequisite_rule.dart';
import 'package:dailytalk_mobile/domain/learning/progression_engine.dart';
import 'package:dailytalk_mobile/presentation/learning_path/learning_map_assembler.dart';
import 'package:dailytalk_mobile/presentation/learning_path/learning_map_view_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'presentation prerequisite tree preserves nested ALL ANY and leaves',
    () {
      final rule = LearningMapPrerequisiteViewModel.group(
        operator: PrerequisiteOperator.all,
        rules: <LearningMapPrerequisiteViewModel>[
          LearningMapPrerequisiteViewModel.group(
            operator: PrerequisiteOperator.any,
            rules: <LearningMapPrerequisiteViewModel>[
              LearningMapPrerequisiteViewModel.activityCompleted(
                activityId: 'activity-a',
                sourcePathElementId: 'element-a',
              ),
              LearningMapPrerequisiteViewModel.activityCompleted(
                activityId: 'activity-b',
                sourcePathElementId: 'element-b',
              ),
            ],
          ),
          LearningMapPrerequisiteViewModel.competencyAchieved(
            competencyId: 'competency-pronunciation',
          ),
        ],
      );

      expect(rule.type, LearningMapPrerequisiteType.group);
      expect(rule.operator, PrerequisiteOperator.all);
      expect(rule.rules, hasLength(2));

      final any = rule.rules.first;

      expect(any.type, LearningMapPrerequisiteType.group);
      expect(any.operator, PrerequisiteOperator.any);
      expect(any.rules, hasLength(2));

      expect(rule.activitySourcePathElementIds.toList(), <String>[
        'element-a',
        'element-b',
      ]);

      expect(rule.requiredCompetencyIds.toList(), <String>[
        'competency-pronunciation',
      ]);
    },
  );

  test(
    'assembler preserves authored prerequisite topology without evaluation',
    () {
      final path = _buildPath();

      final model = const LearningMapAssembler().build(
        learningPath: path,
        packageVersion: 7,
        recoveredFromFallback: false,
        locale: 'en',
        projection: _projectionFor(path),
        syncStates: const <String, ProgressSyncState>{},
      );

      final elements = <String, LearningMapElementViewModel>{
        for (final element in model.elements) element.pathElementId: element,
      };

      final direct = elements['element-b']!.prerequisites!;

      expect(direct.type, LearningMapPrerequisiteType.activityCompleted);
      expect(direct.activityId, 'activity-a');
      expect(direct.sourcePathElementId, 'element-a');

      final root = elements['element-c']!.prerequisites!;

      expect(root.type, LearningMapPrerequisiteType.group);
      expect(root.operator, PrerequisiteOperator.all);
      expect(root.rules, hasLength(2));

      final any = root.rules.first;

      expect(any.type, LearningMapPrerequisiteType.group);
      expect(any.operator, PrerequisiteOperator.any);
      expect(any.rules, hasLength(2));

      expect(any.rules[0].activityId, 'activity-a');
      expect(any.rules[0].sourcePathElementId, 'element-a');

      expect(any.rules[1].activityId, 'activity-b');
      expect(any.rules[1].sourcePathElementId, 'element-b');

      final competency = root.rules[1];

      expect(competency.type, LearningMapPrerequisiteType.competencyAchieved);
      expect(competency.competencyId, 'competency-pronunciation');
      expect(competency.sourcePathElementId, isNull);

      expect(
        elements['element-c']!.authoredPredecessorPathElementIds.toList(),
        <String>['element-a', 'element-b'],
      );

      expect(elements['element-c']!.requiredCompetencyIds.toList(), <String>[
        'competency-pronunciation',
      ]);

      final checkpoint = elements['checkpoint-after-b']!.prerequisites!;

      expect(checkpoint.type, LearningMapPrerequisiteType.activityCompleted);
      expect(checkpoint.activityId, 'activity-b');
      expect(checkpoint.sourcePathElementId, 'element-b');
    },
  );

  test('ambiguous activity occurrence never invents a visual source edge', () {
    final path = _buildPath(duplicateActivityAElement: true);

    final model = const LearningMapAssembler().build(
      learningPath: path,
      packageVersion: 7,
      recoveredFromFallback: false,
      locale: 'en',
      projection: _projectionFor(path),
      syncStates: const <String, ProgressSyncState>{},
    );

    final elements = <String, LearningMapElementViewModel>{
      for (final element in model.elements) element.pathElementId: element,
    };

    final direct = elements['element-b']!.prerequisites!;

    expect(direct.activityId, 'activity-a');

    // The authored domain reference is retained, but there are two possible
    // visual PathElements for the same activity. Presentation must not guess.
    expect(direct.sourcePathElementId, isNull);

    final root = elements['element-c']!.prerequisites!;
    final any = root.rules.first;

    expect(any.rules[0].activityId, 'activity-a');
    expect(any.rules[0].sourcePathElementId, isNull);

    // activity-b remains unambiguous.
    expect(any.rules[1].sourcePathElementId, 'element-b');
  });
}

LearningPath _buildPath({bool duplicateActivityAElement = false}) {
  final activityA = ActivityId('activity-a');
  final activityB = ActivityId('activity-b');
  final activityC = ActivityId('activity-c');

  final competency = CompetencyId('competency-pronunciation');

  final elements = <PathElement>[
    PathElement(
      id: PathElementId('element-a'),
      type: PathElementType.activity,
      activityId: activityA,
      practicePreference: PracticePreference.vocabulary,
    ),
    if (duplicateActivityAElement)
      PathElement(
        id: PathElementId('element-a-copy'),
        type: PathElementType.activity,
        activityId: activityA,
        practicePreference: PracticePreference.vocabulary,
      ),
    PathElement(
      id: PathElementId('element-b'),
      type: PathElementType.activity,
      activityId: activityB,
      prerequisites: ActivityCompletedRequirement(activityA),
      practicePreference: PracticePreference.dialogue,
    ),
    PathElement(
      id: PathElementId('element-c'),
      type: PathElementType.activity,
      activityId: activityC,
      prerequisites: PrerequisiteGroup.all(<PrerequisiteRule>[
        PrerequisiteGroup.any(<PrerequisiteRule>[
          ActivityCompletedRequirement(activityA),
          ActivityCompletedRequirement(activityB),
        ]),
        CompetencyAchievedRequirement(competency),
      ]),
      practicePreference: PracticePreference.speech,
    ),
    PathElement(
      id: PathElementId('checkpoint-after-b'),
      type: PathElementType.checkpoint,
      prerequisites: ActivityCompletedRequirement(activityB),
    ),
  ];

  return LearningPath(
    id: LearningPathId('path-topology'),
    schemaVersion: SchemaVersion(1),
    defaultLocale: 'en',
    title: LocalizedText(<String, String>{'en': 'Mobility path'}),
    journeys: <Journey>[
      Journey(
        id: JourneyId('journey-1'),
        title: LocalizedText(<String, String>{'en': 'Arrival journey'}),
        stages: <Stage>[
          Stage(
            id: StageId('stage-1'),
            title: LocalizedText(<String, String>{'en': 'Arrival'}),
            elements: elements,
          ),
        ],
      ),
    ],
    activities: <Activity>[
      _activity(activityA, competency),
      _activity(activityB, competency),
      _activity(activityC, competency),
    ],
    competencies: <Competency>[
      Competency(
        id: competency,
        title: LocalizedText(<String, String>{'en': 'Pronunciation'}),
        description: LocalizedText(<String, String>{
          'en': 'Basic pronunciation competency.',
        }),
      ),
    ],
  );
}

Activity _activity(ActivityId id, CompetencyId competency) {
  final revisionId = RevisionId('${id.value}.revision-1');

  return Activity(
    id: id,
    type: LearningActivityType.dialogue,
    origin: ContentOrigin.official,
    currentRevisionId: revisionId,
    revisions: <ActivityRevision>[
      ActivityRevision(
        id: revisionId,
        activityId: id,
        revisionNumber: 1,
        title: LocalizedText(<String, String>{'en': id.value}),
        instructions: LocalizedText(<String, String>{
          'en': 'Practice this mission.',
        }),
        visibility: ContentVisibility.public,
        competencies: <CompetencyId>{competency},
      ),
    ],
  );
}

List<LearningProgressProjectionEntry> _projectionFor(LearningPath path) {
  final entries = <LearningProgressProjectionEntry>[];
  var sequence = 0;

  for (final journey in path.journeys) {
    for (final stage in journey.stages) {
      for (final element in stage.elements) {
        entries.add(
          LearningProgressProjectionEntry(
            pathElementId: element.id.value,
            activityId: element.activityId?.value,
            state: LearningActivityState.available,
            reason: ProgressionReason.ready,
            recommendationRank: null,
            packageVersion: 7,
            updatedAt: DateTime.utc(2026, 9, 14, 10, sequence++),
          ),
        );
      }
    }
  }

  return entries;
}
