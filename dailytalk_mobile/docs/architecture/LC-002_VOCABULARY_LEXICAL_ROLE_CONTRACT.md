# LC-002 - Vocabulary Lexical Role Contract

## Status

Approved for the Phase 1 Lesson 3 increment.

This contract clarifies the semantics already present in lexical schema version 1.
It does not add or remove JSON fields and therefore does not require a schema bump.

## Scope

The rules below apply to activities whose type is `vocabulary`.

## Canonical execution set

For vocabulary activities:

`execution.items == practises`

`practises` is the canonical lexical set actually executed by the activity.

## New lexical content

`introduces` is a subset of `practises`.

An item in `introduces` is being explicitly taught as new lexical content in that
activity.

## Retrieval and consolidation

`reinforces` is a subset of `practises`.

An item in `reinforces` is being intentionally retrieved or consolidated rather
than introduced as new content.

For vocabulary activities:

`introduces intersect reinforces == empty`

The same lexical item cannot be classified as both new and review material in the
same vocabulary activity.

## Coverage across the journey

The existing `LearningLexicalCoverageValidator` remains authoritative for lexical
coverage across stages.

Lexical content consumed by an activity must be covered by vocabulary introduced
in the same stage or an earlier stage, preserving parallel practice choices inside
a stage.

## Lesson 3 application

`arrival.vocabulary-03.revision-01` executes eight lexical items.

New content (`introduces`):

- `water`
- `i-am-hungry`
- `i-am-thirsty`
- `can-i-have-more-please`
- `i-dont-eat-meat`

Review (`reinforces`):

- `thank-you`
- `please`
- `bathroom`

All eight are listed in `practises`.

## Future adaptive review

Adaptive selection is outside this contract revision.

When adaptive vocabulary slots are introduced, they must preserve the lexical role
semantics defined here and must not reclassify review items as new content merely
to satisfy validation.
